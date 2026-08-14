import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../services/auth_service.dart';
import '../../services/email_verification_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String? password;
  final String? name;
  final String? phoneNumber;
  final bool isSignUpFlow;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.password,
    this.name,
    this.phoneNumber,
    this.isSignUpFlow = false,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final TextEditingController _codeController = TextEditingController();
  final EmailVerificationService _verificationService = EmailVerificationService();
  final AuthService _authService = AuthService();

  bool _isVerifying = false;
  bool _isResending = false;
  int _cooldownSeconds = 60;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    setState(() => _cooldownSeconds = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
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
      // 1. Verify code against Firestore
      await _verificationService.verifyCode(
        email: widget.email,
        code: code,
      );

      // 2. Perform Account Registration or Mark User as Verified
      if (widget.isSignUpFlow && widget.password != null && widget.name != null) {
        final cred = await _authService.signUpWithEmail(
          widget.email,
          widget.password!,
          widget.name!,
          widget.phoneNumber ?? '',
        );

        if (cred?.user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(cred!.user!.uid)
              .update({
            'isEmailVerified': true,
            'isVerified': true,
            'verificationStatus': 'verified',
          });
        }
      } else {
        // Sign in or update current profile
        if (widget.password != null) {
          final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: widget.email,
            password: widget.password!,
          );
          if (cred.user != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(cred.user!.uid)
                .update({
              'isEmailVerified': true,
              'isVerified': true,
              'verificationStatus': 'verified',
            });
          }
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Email verified successfully! Welcome to DateDash.'),
          backgroundColor: Colors.green,
        ),
      );

      // Pop back to root or home screen
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on EmailVerificationException catch (e) {
      setState(() => _errorMessage = e.message);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Authentication failed.');
    } catch (e) {
      setState(() => _errorMessage = 'Could not verify code: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleResendCode() async {
    if (_cooldownSeconds > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await _verificationService.requestCode(widget.email);
      _startCooldownTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code sent to ${widget.email}'),
            backgroundColor: const Color(0xFFFF4D85),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not resend code. Please try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14141A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

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
                    Iconsax.sms_tracking,
                    size: 44,
                    color: Color(0xFFFF4D85),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Verify Your Email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 10),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit verification code to\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Code Input Card
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
                      decoration: InputDecoration(
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

              // Verify Button
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
                  shadowColor: const Color(0xFFFF4D85).withValues(alpha: 0.4),
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
                    : const Text(
                        'VERIFY & CONTINUE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),

              const SizedBox(height: 20),

              // Resend Code Action
              Center(
                child: TextButton(
                  onPressed: (_cooldownSeconds > 0 || _isResending)
                      ? null
                      : _handleResendCode,
                  child: Text(
                    _cooldownSeconds > 0
                        ? 'Resend code in ${_cooldownSeconds}s'
                        : 'Didn\'t get the code? Resend Code',
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
          ),
        ),
      ),
    );
  }
}
