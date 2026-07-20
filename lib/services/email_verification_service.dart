import 'dart:convert';

import 'package:http/http.dart' as http;

class EmailVerificationService {
  static const String _baseUrl = String.fromEnvironment(
    'EMAIL_VERIFICATION_API_BASE_URL',
    defaultValue: 'https://us-central1-datedash-35789.cloudfunctions.net',
  );

  Future<void> requestCode(String email) async {
    await _post(
      'requestEmailVerification',
      {'email': email},
    );
  }

  Future<void> verifyCode({
    required String email,
    required String code,
  }) async {
    await _post(
      'verifyEmailCode',
      {
        'email': email,
        'code': code,
      },
    );
  }

  Future<void> _post(String endpoint, Map<String, String> body) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/$endpoint'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String? error;
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        error = payload['error']?.toString();
      }
    } catch (_) {
      error = null;
    }

    throw EmailVerificationException(error ?? 'Email verification failed.');
  }
}

class EmailVerificationException implements Exception {
  EmailVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}
