import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class IdentityVerificationService {
  static const String _baseUrl = String.fromEnvironment(
    'IDENTITY_VERIFICATION_API_BASE_URL',
    defaultValue: 'https://us-central1-datedash-35789.cloudfunctions.net',
  );

  Future<String> createVerificationLink() async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    if (idToken == null) {
      throw IdentityVerificationException('Please sign in again.');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/createIdentityVerificationLink'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': user?.email,
        'phone': user?.phoneNumber,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        final url = payload['url']?.toString();
        if (url != null && url.isNotEmpty) return url;
      }
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

    throw IdentityVerificationException(
      error ?? 'Could not start identity verification.',
    );
  }
}

class IdentityVerificationException implements Exception {
  IdentityVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}
