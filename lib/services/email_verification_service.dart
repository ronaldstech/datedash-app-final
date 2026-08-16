import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EmailVerificationService {
  /// PHP email API endpoint (Resend-backed, live on hosting server)
  static String phpApiUrl = const String.fromEnvironment(
    'PHP_EMAIL_API_URL',
    defaultValue: 'https://apexspacemw.com/rt/php_backend/send_verification_code.php',
  );

  static const String _baseUrl = String.fromEnvironment(
    'EMAIL_VERIFICATION_API_BASE_URL',
    defaultValue: 'https://us-central1-datedash-35789.cloudfunctions.net',
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generates a 6-digit OTP code, stores it in Firestore `email_verifications`,
  /// dispatches via PHP hosting email API, and returns the 6-digit code.
  Future<String> requestCode(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final randomCode = (100000 + Random().nextInt(900000)).toString();

    try {
      await _firestore.collection('email_verifications').doc(cleanEmail).set({
        'email': cleanEmail,
        'code': randomCode,
        'verified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 15)),
        ),
      }, SetOptions(merge: true));

      debugPrint('🔑 EMAIL VERIFICATION CODE FOR [$cleanEmail]: $randomCode');

      // 1. Dispatch via PHP Hosting Backend if URL is configured
      if (phpApiUrl.isNotEmpty) {
        try {
          final res = await http.post(
            Uri.parse(phpApiUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': cleanEmail, 'code': randomCode}),
          ).timeout(const Duration(seconds: 6));
          debugPrint('PHP Email Delivery Response [${res.statusCode}]: ${res.body}');
        } catch (e) {
          debugPrint('PHP email backend dispatch error: $e');
        }
      }

      // 2. Fallback: Cloud Function attempt if available
      try {
        await http.post(
          Uri.parse('$_baseUrl/requestEmailVerification'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': cleanEmail, 'code': randomCode}),
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Cloud function note: using Firestore verification OTP ($randomCode)');
      }

      // Send Firebase Auth email verification link as well if user is signed in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email?.toLowerCase() == cleanEmail) {
        try {
          await currentUser.sendEmailVerification();
        } catch (_) {}
      }

      return randomCode;
    } catch (e) {
      debugPrint('Error storing verification code in Firestore: $e');
      throw EmailVerificationException('Could not generate verification code. Please try again.');
    }
  }

  /// Verifies the 6-digit OTP code against Firestore `email_verifications`.
  Future<bool> verifyCode({
    required String email,
    required String code,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final inputCode = code.trim();

    try {
      final doc = await _firestore
          .collection('email_verifications')
          .doc(cleanEmail)
          .get();

      if (!doc.exists) {
        throw EmailVerificationException(
          'No verification code found for $cleanEmail. Please request a new code.',
        );
      }

      final data = doc.data();
      final storedCode = data?['code']?.toString();
      final expiresAt = (data?['expiresAt'] as Timestamp?)?.toDate();

      if (storedCode == null || storedCode != inputCode) {
        throw EmailVerificationException(
          'Invalid verification code. Please check your code and try again.',
        );
      }

      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        throw EmailVerificationException(
          'Verification code has expired. Please request a new code.',
        );
      }

      // Mark email as verified in Firestore
      await _firestore
          .collection('email_verifications')
          .doc(cleanEmail)
          .update({
            'verified': true,
            'verifiedAt': FieldValue.serverTimestamp(),
          });

      // Update active user profile if logged in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email?.toLowerCase() == cleanEmail) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'isEmailVerified': true,
          'isVerified': true,
          'verificationStatus': 'verified',
        });
      }

      return true;
    } on EmailVerificationException {
      rethrow;
    } catch (e) {
      debugPrint('Error verifying email code: $e');
      throw EmailVerificationException(
        'Could not verify code. Please check your network connection.',
      );
    }
  }

  /// Checks if an email is marked as verified in Firestore
  Future<bool> isEmailVerified(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final doc = await _firestore
          .collection('email_verifications')
          .doc(cleanEmail)
          .get();
      if (!doc.exists) return false;
      return (doc.data()?['verified'] == true);
    } catch (_) {
      return false;
    }
  }
}

class EmailVerificationException implements Exception {
  EmailVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}
