import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:datedash/models/payment_operator_model.dart';

class PaymentService {
  static const String _operatorsEndpoint =
      'https://unimarket-mw.com/datedash/api/paychangu/get_operators.php';
  static const String _initEndpoint =
      'https://unimarket-mw.com/datedash/api/paychangu/initialize_payment.php';
  static const String _verifyEndpoint =
      'https://unimarket-mw.com/datedash/api/paychangu/verify_payment.php';

  /// Fetches the supported mobile money operators from the remote backend.
  Future<List<PaymentOperator>> getMobileOperators() async {
    try {
      final response = await http.get(Uri.parse(_operatorsEndpoint));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          final List<dynamic> data = responseData['data'];
          return data.map((json) => PaymentOperator.fromJson(json)).toList();
        } else {
          throw Exception(
              responseData['message'] ?? 'Failed to load operators');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Initializes a payment through the backend bridge to PayChangu.
  Future<Map<String, dynamic>> initializePayment({
    required String mobile,
    required double amount,
    required String email,
    required String operatorId,
    int? txRef, // Unique integer reference
    String? firstName,
    String? lastName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_initEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'mobile': mobile,
          'amount': amount,
          'email': email,
          'operator_id': operatorId,
          'txRef': txRef,
          'first_name': firstName ?? 'User',
          'last_name': lastName ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success' || data['message'] == 'Transaction initialized successfully' || data['message'] == 'Payment initiated successfully.') {
          // Return the full 'data' object which contains ref_id, trans_id, status etc.
          return data['data'] ?? data;
        } else {
          throw Exception(data['message'] ?? 'Initialization failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Payment Initialization failed: $e');
    }
  }

  /// Verifies a payment status using the transaction reference.
  Future<Map<String, dynamic>> verifyPayment(String txRef) async {
    try {
      final response = await http.get(Uri.parse('$_verifyEndpoint?txRef=$txRef'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Verification failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Payment Verification failed: $e');
    }
  }
}
