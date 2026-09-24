import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/sms_service.dart';
import '../landing_screen.dart';
import 'sign_in_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String? password;
  final String? name;
  final String? phoneNumber;
  final bool isSignUpFlow;
  final bool sendCodeOnOpen;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.password,
    this.name,
    this.phoneNumber,
    this.isSignUpFlow = false,
    this.sendCodeOnOpen = false,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final SmsService _smsService = SmsService();

  String _completePhoneNumber = '';
  String? _generatedOtp;
  bool _isLoadingProfile = true;
  bool _isSendingCode = false;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isOtpSent = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPhoneNumber();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initPhoneNumber() async {
    // 1. Check if phoneNumber was explicitly passed in
    if (widget.phoneNumber != null && widget.phoneNumber!.trim().isNotEmpty) {
      _completePhoneNumber = widget.phoneNumber!.trim();
      _phoneController.text = _completePhoneNumber;
      if (mounted) setState(() => _isLoadingProfile = false);
      _sendPhoneOtp();
      return;
    }

    // 2. Otherwise, check current user profile in Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final profile = await _profileService.getUserProfile(user.uid);
        if (profile?.phoneNumber != null &&
            profile!.phoneNumber!.trim().isNotEmpty) {
          _completePhoneNumber = profile.phoneNumber!.trim();
          _phoneController.text = _completePhoneNumber;
          if (mounted) setState(() => _isLoadingProfile = false);
          _sendPhoneOtp();
          return;
        }
      } catch (e) {
        debugPrint('Error loading user profile phone: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoadingProfile = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _sendPhoneOtp({bool isResend = false}) async {
    final phone = _completePhoneNumber.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid phone number');
      return;
    }

    setState(() {
      if (isResend) {
        _isResending = true;
      } else {
        _isSendingCode = true;
      }
      _errorMessage = null;
    });

    try {
      // 1. Generate 6-digit OTP code
      final otpCode = _smsService.generateOtpCode();
      _generatedOtp = otpCode;

      // 2. Save OTP to Firestore if user exists
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _profileService.savePhoneOtp(
          uid: user.uid,
          code: otpCode,
        );
      }

      // 3. Dispatch SMS via Telcomw
      final sent = await _smsService.sendOtp(
        phoneNumber: phone,
        code: otpCode,
      );

      if (!sent) {
        debugPrint('Warning: Telcomw SMS API request failed or credentials missing.');
      }

      setState(() {
        _isOtpSent = true;
        _isSendingCode = false;
        _isResending = false;
      });

      _startCooldown();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF111827),
            content: Text(
              'Verification code sent to $phone. Enter code to continue.',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSendingCode = false;
        _isResending = false;
        _errorMessage = 'Could not send verification code: ${e.toString()}';
      });
    }
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      // 1. Check code validity
      bool isCodeValid = false;
      if (user != null) {
        isCodeValid = await _profileService.verifyPhoneOtp(
          uid: user.uid,
          code: code,
        );
      }
      // Fallback check against session generated OTP
      if (!isCodeValid && _generatedOtp != null && _generatedOtp == code) {
        isCodeValid = true;
      }

      if (!isCodeValid) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Invalid verification code. Please check and try again.';
        });
        return;
      }

      // 2. Finalize registration if Sign Up Flow
      if (widget.isSignUpFlow &&
          widget.password != null &&
          widget.name != null) {
        final cred = await _authService.signUpWithEmail(
          widget.email,
          widget.password!,
          widget.name!,
          _completePhoneNumber,
        );

        if (cred?.user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(cred!.user!.uid)
              .set({
            'isEmailVerified': true,
            'isPhoneVerified': true,
            'phoneNumber': _completePhoneNumber,
          }, SetOptions(merge: true));
        }
      } else if (user != null) {
        // Mark existing user as verified in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'isEmailVerified': true,
          'isPhoneVerified': true,
          'phoneNumber': _completePhoneNumber,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number verified successfully. Welcome to Snellum!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LandingScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Authentication failed.');
    } catch (e) {
      setState(() => _errorMessage = 'Verification error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF14141A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Iconsax.arrow_left, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.logout, color: Colors.white70),
            tooltip: 'Log out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingProfile
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF4D85)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // Header Badge
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D85).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF4D85).withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Iconsax.mobile5,
                          size: 44,
                          color: Color(0xFFFF4D85),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      lp.getString('verify_phone_code'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      _isOtpSent
                          ? lp
                              .getString('enter_code_sent_to')
                              .replaceAll('{phone}', _completePhoneNumber)
                          : lp.getString('enter_phone_prompt'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // STEP 1: Phone Input (if code not sent yet)
                    if (!_isOtpSent) ...[
                      IntlPhoneField(
                        controller: _phoneController,
                        initialCountryCode: 'MW',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        dropdownTextStyle: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: const TextStyle(color: Colors.white60),
                          hintText: 'Enter phone number',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF4D85),
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (phone) {
                          _completePhoneNumber = phone.completeNumber;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSendingCode ? null : () => _sendPhoneOtp(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D85),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                          shadowColor:
                              const Color(0xFFFF4D85).withValues(alpha: 0.4),
                        ),
                        child: _isSendingCode
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                lp.getString('send_code'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ],

                    // STEP 2: OTP Code Entry (when code has been sent)
                    if (_isOtpSent) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              autofocus: true,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 16.0,
                              ),
                              decoration: const InputDecoration(
                                hintText: '------',
                                hintStyle: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 32,
                                  letterSpacing: 16.0,
                                ),
                                counterText: '',
                                border: InputBorder.none,
                              ),
                              onChanged: (val) {
                                if (val.length == 6) {
                                  _handleVerify();
                                }
                              },
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      ElevatedButton(
                        onPressed: _isVerifying ? null : _handleVerify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D85),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                          shadowColor:
                              const Color(0xFFFF4D85).withValues(alpha: 0.4),
                        ),
                        child: _isVerifying
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                lp.getString('verify_and_continue'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),

                      const SizedBox(height: 16),

                      // Change Phone Number Action
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isOtpSent = false;
                              _errorMessage = null;
                              _codeController.clear();
                            });
                          },
                          icon: const Icon(
                            Iconsax.edit,
                            size: 16,
                            color: Colors.white70,
                          ),
                          label: Text(
                            lp.getString('change_phone_number'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Resend Code Action
                      Center(
                        child: TextButton(
                          onPressed: (_cooldownSeconds > 0 || _isResending)
                              ? null
                              : () => _sendPhoneOtp(isResend: true),
                          child: Text(
                            _cooldownSeconds > 0
                                ? lp.getString('resend_available_in').replaceAll(
                                      '{sec}',
                                      '$_cooldownSeconds',
                                    )
                                : lp.getString('resend_code_sms'),
                            style: TextStyle(
                              color: _cooldownSeconds > 0
                                  ? Colors.white38
                                  : const Color(0xFFFF4D85),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
