import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String uid;
  final String txRef;
  final String? chargeId;
  final double amount;
  final String status; // 'pending', 'success', 'failed'
  final String type; // 'subscription', 'credits'
  final String? plan; // 'Pro', 'Premium', 'Elite'
  final int? creditAmount;
  final String operator;
  final DateTime timestamp;

  TransactionModel({
    required this.id,
    required this.uid,
    required this.txRef,
    this.chargeId,
    required this.amount,
    required this.status,
    required this.type,
    this.plan,
    this.creditAmount,
    required this.operator,
    required this.timestamp,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map, String docId) {
    return TransactionModel(
      id: docId,
      uid: map['uid'] ?? '',
      txRef: (map['txRef'] ?? '').toString(),
      chargeId: map['charge_id']?.toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
      type: map['type'] ?? '',
      plan: map['plan'],
      creditAmount: map['creditAmount'] as int?,
      operator: map['operator'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'txRef': txRef,
      'charge_id': chargeId,
      'amount': amount,
      'status': status,
      'type': type,
      'plan': plan,
      'creditAmount': creditAmount,
      'operator': operator,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
