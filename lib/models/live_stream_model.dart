import 'package:cloud_firestore/cloud_firestore.dart';

class LiveStream {
  final String id;
  final String broadcasterId;
  final String broadcasterName;
  final String broadcasterPhoto;
  final int viewerCount;
  final String title;
  final String status;
  final DateTime startedAt;
  final String? guestId;
  final String? guestName;
  final String? guestPhoto;
  final String? guestStatus;

  LiveStream({
    required this.id,
    required this.broadcasterId,
    required this.broadcasterName,
    required this.broadcasterPhoto,
    this.viewerCount = 0,
    required this.title,
    this.status = 'active',
    required this.startedAt,
    this.guestId,
    this.guestName,
    this.guestPhoto,
    this.guestStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'broadcasterId': broadcasterId,
      'broadcasterName': broadcasterName,
      'broadcasterPhoto': broadcasterPhoto,
      'viewerCount': viewerCount,
      'title': title,
      'status': status,
      'startedAt': FieldValue.serverTimestamp(),
      'guestId': guestId,
      'guestName': guestName,
      'guestPhoto': guestPhoto,
      'guestStatus': guestStatus,
    };
  }

  factory LiveStream.fromMap(Map<String, dynamic> map, String id) {
    return LiveStream(
      id: id,
      broadcasterId: map['broadcasterId'] ?? '',
      broadcasterName: map['broadcasterName'] ?? '',
      broadcasterPhoto: map['broadcasterPhoto'] ?? '',
      viewerCount: map['viewerCount'] ?? 0,
      title: map['title'] ?? '',
      status: map['status'] ?? 'active',
      startedAt: (map['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      guestId: map['guestId'],
      guestName: map['guestName'],
      guestPhoto: map['guestPhoto'],
      guestStatus: map['guestStatus'],
    );
  }
}

class LiveChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderPhoto;
  final String message;
  final String? giftType;
  final int? giftValue;
  final DateTime timestamp;

  LiveChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderPhoto,
    required this.message,
    this.giftType,
    this.giftValue,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'message': message,
      'giftType': giftType,
      'giftValue': giftValue,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  factory LiveChatMessage.fromMap(Map<String, dynamic> map, String id) {
    return LiveChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderPhoto: map['senderPhoto'] ?? '',
      message: map['message'] ?? '',
      giftType: map['giftType'],
      giftValue: map['giftValue'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
