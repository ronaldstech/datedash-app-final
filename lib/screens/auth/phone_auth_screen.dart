import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/sms_service.dart';
import '../landing_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _authService = AuthService();
  final _profileService = ProfileService();
  final _smsService = SmsService();

  String _completePhoneNumber = '';
  String? _matchedUid;
  bool _isLoading = false;
  bool _isOtpSent = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
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

  /// Step 1: Look up matching number in Firestore, generate 6-digit OTP,
  /// save to Firestore directly in the user document, and dispatch via Telcomw SMS API.
  Future<void> _sendOtp() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final lp = context.read<LanguageProvider>();
    if (_completePhoneNumber.trim().isEmpty) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(lp.getString('valid_phone_required'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Search Firestore for a user profile with matching phone number
      final profile = await _profileService.findUserByPhoneNumber(_completePhoneNumber);

      if (profile == null || profile.uid == null) {
        setState(() => _isLoading = false);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(lp.getString('no_account_found_phone')),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      _matchedUid = profile.uid;

      // 2. Generate secure 6-digit code
      final otpCode = _smsService.generateOtpCode();

      // 3. Save OTP code in Firestore user doc
      await _profileService.savePhoneOtp(
        uid: _matchedUid!,
        code: otpCode,
      );

      // 4. Send code via Telcomw SMS API
      final sent = await _smsService.sendOtp(
        phoneNumber: _completePhoneNumber,
        code: otpCode,
      );

      if (!sent) {
        debugPrint('Warning: Telcomw SMS API request failed or credentials missing.');
      }

      setState(() {
        _isOtpSent = true;
        _isLoading = false;
      });

      _startCooldown();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF111827),
          content: Text(
            'Verification code sent to $_completePhoneNumber',
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
  /// Step 2: Validate code against Firestore document, then custom log in
  /// with Firebase Auth using the user's UID.
  Future<void> _verifyOtp() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final lp = context.read<LanguageProvider>();
    final enteredCode = _otpController.text.trim();

    if (enteredCode.length < 6) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(lp.getString('enter_full_6_digit_code'))),
      );
      return;
    }

    if (_matchedUid == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Session expired. Please re-enter your number.')),
      );
      setState(() => _isOtpSent = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Check code against user's Firestore document
      final isCodeValid = await _profileService.verifyPhoneOtp(
        uid: _matchedUid!,
        code: enteredCode,
      );

      if (!isCodeValid) {
        setState(() => _isLoading = false);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Invalid verification code. Please check and try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      // 2. Obtain custom token from server or sign in directly
      try {
        final customToken = await _authService.fetchCustomTokenForUid(_matchedUid!);
        await _authService.signInWithCustomToken(customToken);
      } catch (authErr) {
        debugPrint('Custom token server sign-in notice: $authErr');
        // If server returned an error or is still being configured, verify if profile has email
        // or rethrow with clear guidance
        rethrow;
      }

      if (mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LandingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Login failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lp = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_2, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Icon(
                _isOtpSent ? Iconsax.message_notif : Iconsax.mobile,
                size: 80,
                color: const Color(0xFFFF4D85),
              ),
              const SizedBox(height: 32),
              Text(
                _isOtpSent
                    ? lp.getString('verify_phone_code')
                    : lp.getString('continue_with_phone'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isOtpSent
                    ? lp
                        .getString('enter_code_sent_to')
                        .replaceAll('{phone}', _completePhoneNumber)
                    : lp.getString('enter_phone_prompt'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).hintColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              if (!_isOtpSent)
                IntlPhoneField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: lp.getString('languages_spoken_label') != 'languages_spoken_label'
                        ? 'Phone Number'
                        : 'Phone Number',
                    labelStyle: TextStyle(color: Theme.of(context).hintColor),
                    hintStyle: TextStyle(
                      color: Theme.of(context).hintColor.withValues(alpha: 0.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF4D85),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.02),
                  ),
                  initialCountryCode: 'MW',
                  onChanged: (phone) {
                    _completePhoneNumber = phone.completeNumber;
                  },
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  dropdownTextStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  cursorColor: const Color(0xFFFF4D85),
                )
              else ...[
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 12,
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: TextStyle(
                        color: Theme.of(context).hintColor.withValues(alpha: 0.3),
                        letterSpacing: 12,
                      ),
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
                if (_cooldownSeconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      lp
                          .getString('resend_available_in')
                          .replaceAll('{sec}', '$_cooldownSeconds'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    child: Text(
                      lp.getString('resend_code_sms'),
                      style: const TextStyle(
                        color: Color(0xFFFF4D85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : (_isOtpSent ? _verifyOtp : _sendOtp),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D85),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0xFFFF4D85).withValues(alpha: 0.5),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _isOtpSent
                            ? lp.getString('verify_and_continue')
                            : lp.getString('send_code'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              if (_isOtpSent) ...[
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                            _isOtpSent = false;
                            _otpController.clear();
                          }),
                  child: Text(
                    lp.getString('change_phone_number'),
                    style: const TextStyle(
                      color: Color(0xFFFF4D85),
                      fontWeight: FontWeight.bold,
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
