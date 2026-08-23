import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EmailVerificationService {
  /// Brevo API Key (configurable via --dart-define=BREVO_API_KEY=your_key)
  static const String brevoApiKey = String.fromEnvironment(
    'BREVO_API_KEY',
    defaultValue: '',
  );

  /// Verified sender email in Brevo
  static const String brevoSenderEmail = String.fromEnvironment(
    'BREVO_SENDER_EMAIL',
    defaultValue: 'no-reply@snellum.app',
  );

  /// Sender display name
  static const String brevoSenderName = String.fromEnvironment(
    'BREVO_SENDER_NAME',
    defaultValue: 'Snellum',
  );

  /// PHP email API endpoint (fallback / hosting server)
  static String phpApiUrl = const String.fromEnvironment(
    'PHP_EMAIL_API_URL',
    defaultValue:
        'https://apexspacemw.com/rt/php_backend/send_verification_code.php',
  );

  static const String _baseUrl = String.fromEnvironment(
    'EMAIL_VERIFICATION_API_BASE_URL',
    defaultValue: 'https://us-central1-snellum.cloudfunctions.net',
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sends a branded OTP verification email using Brevo (formerly Sendinblue) Transactional API v3.
  Future<bool> _sendBrevoEmail({
    required String recipientEmail,
    required String code,
    String? recipientName,
  }) async {
    if (brevoApiKey.trim().isEmpty) {
      debugPrint(
        'Brevo API Key not provided, falling back to alternative dispatchers.',
      );
      return false;
    }

    final url = Uri.parse('https://api.brevo.com/v3/smtp/email');
    final htmlContent =
        '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Snellum Email Verification</title>
</head>
<body style="margin: 0; padding: 24px 16px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f4f5f7; color: #111827;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 520px; background-color: #ffffff; margin: 0 auto; border: 1px solid #e5e7eb;">
    <tr>
      <td style="padding: 28px 28px 8px;">
        <p style="margin: 0 0 20px; color: #111827; font-size: 18px; font-weight: 700;">Snellum</p>
        <h1 style="margin: 0 0 12px; color: #111827; font-size: 22px; font-weight: 700;">Verify your email address</h1>
        <p style="margin: 0 0 24px; color: #4b5563; font-size: 15px; line-height: 22px;">
          Use the verification code below to finish setting up your Snellum account.
        </p>
      </td>
    </tr>
    <tr>
      <td style="padding: 0 28px 24px;">
        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #f9fafb; border: 1px solid #e5e7eb;">
          <tr>
            <td style="padding: 18px 16px; text-align: center;">
              <span style="color: #111827; font-family: 'Courier New', Courier, monospace; font-size: 32px; font-weight: 700; letter-spacing: 6px;">$code</span>
            </td>
          </tr>
        </table>
        <p style="margin: 18px 0 0; color: #4b5563; font-size: 14px; line-height: 21px;">
          This code is valid for <strong>15 minutes</strong>.
        </p>
        <p style="margin: 18px 0 0; padding-top: 18px; border-top: 1px solid #e5e7eb; color: #6b7280; font-size: 13px; line-height: 19px;">
          If you didn't create an account with Snellum, you can safely disregard this message.
        </p>
      </td>
    </tr>
  </table>
</body>
</html>
''';

    try {
      final response = await http
          .post(
            url,
            headers: {
              'accept': 'application/json',
              'api-key': brevoApiKey.trim(),
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'sender': {'name': brevoSenderName, 'email': brevoSenderEmail},
              'to': [
                {
                  'email': recipientEmail,
                  'name': recipientName ?? recipientEmail.split('@').first,
                },
              ],
              'subject': 'Your Snellum Verification Code: $code',
              'htmlContent': htmlContent,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Brevo email delivered successfully to $recipientEmail');
        return true;
      } else {
        debugPrint(
          'Brevo API returned status [${response.statusCode}]: ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Error contacting Brevo API: $e');
      return false;
    }
  }

  /// Generates a 6-digit OTP code, stores it in Firestore `email_verifications`,
  /// dispatches via Brevo (with fallback to PHP backend / Cloud Functions),
  /// and returns the 6-digit code.
  Future<String> requestCode(String email, {String? recipientName}) async {
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

      debugPrint('EMAIL VERIFICATION CODE FOR [$cleanEmail]: $randomCode');

      // 1. Dispatch via Brevo API
      bool sentViaBrevo = false;
      if (brevoApiKey.isNotEmpty) {
        sentViaBrevo = await _sendBrevoEmail(
          recipientEmail: cleanEmail,
          code: randomCode,
          recipientName: recipientName,
        );
      }

      // 2. If Brevo not used or failed, dispatch via PHP Hosting Backend
      if (!sentViaBrevo && phpApiUrl.isNotEmpty) {
        try {
          final res = await http
              .post(
                Uri.parse(phpApiUrl),
                headers: const {'Content-Type': 'application/json'},
                body: jsonEncode({'email': cleanEmail, 'code': randomCode}),
              )
              .timeout(const Duration(seconds: 6));
          debugPrint(
            'PHP Email Delivery Response [${res.statusCode}]: ${res.body}',
          );
        } catch (e) {
          debugPrint('PHP email backend dispatch error: $e');
        }
      }

      // 3. Fallback: Cloud Function attempt if available
      try {
        await http
            .post(
              Uri.parse('$_baseUrl/requestEmailVerification'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'email': cleanEmail, 'code': randomCode}),
            )
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint(
          'Cloud function note: using Firestore verification OTP ($randomCode)',
        );
      }

      // Send Firebase Auth email verification link as well if user is signed in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null &&
          currentUser.email?.toLowerCase() == cleanEmail) {
        try {
          await currentUser.sendEmailVerification();
        } catch (_) {}
      }

      return randomCode;
    } catch (e) {
      debugPrint('Error storing verification code in Firestore: $e');
      throw EmailVerificationException(
        'Could not generate verification code. Please try again.',
      );
    }
  }

  /// Verifies the 6-digit OTP code against Firestore `email_verifications`.
  Future<bool> verifyCode({required String email, required String code}) async {
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
      await _firestore.collection('email_verifications').doc(cleanEmail).update(
        {'verified': true, 'verifiedAt': FieldValue.serverTimestamp()},
      );

      // Update active user profile if logged in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null &&
          currentUser.email?.toLowerCase() == cleanEmail) {
        await _firestore.collection('users').doc(currentUser.uid).set({
          'isEmailVerified': true,
          'isVerified': true,
          'verificationStatus': 'verified',
        }, SetOptions(merge: true));
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
