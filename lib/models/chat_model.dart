import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, voice, gif, sticker, call, meetup, gift }

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final bool isDelivered;
  final MessageType messageType;
  final String? mediaUrl; // URL for image, voice, GIF
  final int? voiceDuration; // Duration in milliseconds for voice messages
  final bool isEdited;
  final bool isDeleted;
  final String? giftType;
  final int? giftValue;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderName;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.isDelivered = true,
    this.messageType = MessageType.text,
    this.mediaUrl,
    this.voiceDuration,
    this.isEdited = false,
    this.isDeleted = false,
    this.giftType,
    this.giftValue,
    this.replyToId,
    this.replyToText,
    this.replyToSenderName,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      isDelivered: data['isDelivered'] ?? true,
      messageType: _parseMessageType(data['messageType'] ?? 'text'),
      mediaUrl: data['mediaUrl'],
      voiceDuration: data['voiceDuration'],
      isEdited: data['isEdited'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      giftType: data['giftType'],
      giftValue: data['giftValue'],
      replyToId: data['replyToId'],
      replyToText: data['replyToText'],
      replyToSenderName: data['replyToSenderName'],
    );
  }

  static MessageType _parseMessageType(String type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'voice':
        return MessageType.voice;
      case 'gif':
        return MessageType.gif;
      case 'sticker':
        return MessageType.sticker;
      case 'call':
        return MessageType.call;
      case 'meetup':
        return MessageType.meetup;
      case 'gift':
        return MessageType.gift;
      default:
        return MessageType.text;
    }
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': isRead,
        'isDelivered': isDelivered,
        'messageType': messageType.toString().split('.').last,
        'mediaUrl': mediaUrl,
        'voiceDuration': voiceDuration,
        'isEdited': isEdited,
        'isDeleted': isDeleted,
        'giftType': giftType,
        'giftValue': giftValue,
        'replyToId': replyToId,
        'replyToText': replyToText,
        'replyToSenderName': replyToSenderName,
      };
}

class Chat {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final Map<String, int> unreadCount;
  final bool isSuperRequest;
  final String? requestStatus;
  final String? requestSenderId;

  Chat({
    required this.id,
    required this.participants,
    this.lastMessage = '',
    this.lastMessageTime,
    this.lastMessageSenderId = '',
    this.unreadCount = const {},
    this.isSuperRequest = false,
    this.requestStatus,
    this.requestSenderId,
  });

  factory Chat.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chat(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toInt()),
            ) ??
            {},
      ),
      isSuperRequest: data['isSuperRequest'] ?? false,
      requestStatus: data['requestStatus'],
      requestSenderId: data['requestSenderId'],
    );
  }

  /// Returns the other participant's ID
  String otherUserId(String myUid) =>
      participants.firstWhere((id) => id != myUid, orElse: () => '');
}
