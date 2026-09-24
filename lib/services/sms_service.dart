import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class SmsService {
  /// Sends an OTP message via the Telcomw SMS API.
  /// Formats multipart request as specified:
  /// api_key, password, text, numbers, from
  Future<bool> sendOtp({
    required String phoneNumber,
    required String code,
  }) async {
    try {
      final formattedNumber = _normalizePhoneNumber(phoneNumber);
      final message = 'Your Snellum verification code is: $code';

      debugPrint('SmsService: Sending OTP to $formattedNumber via Telcomw');

      final uri = Uri.parse(AppConfig.telcomApiUrl);
      final request = http.MultipartRequest('POST', uri);

      request.fields.addAll({
        'api_key': AppConfig.telcomApiKey,
        'password': AppConfig.telcomApiPassword,
        'text': message,
        'numbers': formattedNumber,
        'from': AppConfig.telcomSenderId,
      });

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      debugPrint('SmsService response [${streamedResponse.statusCode}]: $responseBody');

      if (streamedResponse.statusCode == 200) {
        return true;
      } else {
        debugPrint('SmsService failed with reason: ${streamedResponse.reasonPhrase}');
        return false;
      }
    } catch (e) {
      debugPrint('SmsService exception: $e');
      return false;
    }
  }

  /// Generates a secure random 6-digit verification code.
  String generateOtpCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Normalizes phone number for Telcomw (e.g. 0884113450 or 0990944406).
  /// If provided in international format +265990944406, strips +265 and prepends 0.
  String _normalizePhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleaned.startsWith('+265')) {
      cleaned = '0${cleaned.substring(4)}';
    } else if (cleaned.startsWith('265')) {
      cleaned = '0${cleaned.substring(3)}';
    }
    return cleaned;
  }
}
