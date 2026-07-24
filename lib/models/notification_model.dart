import 'package:cloud_firestore/cloud_firestore.dart';

class SnellumNotification {
  final String id;
  final String recipientId;
  final String senderId;
  final String senderName;
  final String type; // 'like', 'view', 'gift'
  final DateTime timestamp;
  final bool isRead;
  final String? message;

  SnellumNotification({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.message,
  });

  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'message': message,
    };
  }

  factory SnellumNotification.fromMap(Map<String, dynamic> map, String id) {
    return SnellumNotification(
      id: id,
      recipientId: map['recipientId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      type: map['type'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      message: map['message'],
    );
  }
}
