import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'dart:convert';
import '../models/chat_model.dart';
import 'local_db_service.dart';
import 'profile_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalDbService _localDb = LocalDbService();

  // Change this to your actual PHP server endpoint
  static const String _uploadEndpoint =
      'https://unimarket-mw.com/snellum/api/upload2.php';

  /// Deterministic chat ID — sorted UIDs joined by underscore
  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Creates a chat if it doesn't exist, returns the chat ID
  Future<String> getOrCreateChat(String myUid, String otherUid) async {
    final chatId = getChatId(myUid, otherUid);
    final docRef = _firestore.collection('chats').doc(chatId);
    final doc = await docRef.get();

    final isMatched = await ProfileService().checkMatchStatus(myUid, otherUid);

    if (!doc.exists) {
      await docRef.set({
        'participants': [myUid, otherUid],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
        'unreadCount': {myUid: 0, otherUid: 0},
        'createdAt': FieldValue.serverTimestamp(),
        'requestStatus': isMatched ? 'accepted' : 'pending',
        'requestSenderId': isMatched ? null : myUid,
      });
    } else {
      final data = doc.data() as Map<String, dynamic>;
      if (!isMatched && data['requestStatus'] == null) {
        await docRef.update({
          'requestStatus': 'pending',
          'requestSenderId': myUid,
        });
      }
    }

    return chatId;
  }

  /// Sends a message and updates the chat meta
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
    MessageType messageType = MessageType.text,
    String? replyToId,
    String? replyToText,
    String? replyToSenderName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final msgRef =
        _firestore.collection('chats').doc(chatId).collection('messages').doc();

    // --- Daily Free Message Limit Check ---
    final senderRef = _firestore.collection('users').doc(senderId);
    final senderDoc = await senderRef.get();
    if (senderDoc.exists) {
      final data = senderDoc.data() as Map<String, dynamic>;
      final bool isPremium = data['isPremium'] == true;
      
      if (!isPremium) {
        final String today = DateTime.now().toIso8601String().split('T')[0];
        final String? lastReset = data['lastMessageResetDate']?.toString();
        int dailyCount = (data['dailyMessageCount'] as num?)?.toInt() ?? 0;
        
        if (lastReset != today) {
          dailyCount = 0;
        }
        
        // We no longer throw an exception here. 
        // The client-side handles charging sparks after the 5 free messages are used up.
        
        await senderRef.update({
          'dailyMessageCount': dailyCount + 1,
          'lastMessageResetDate': today,
        });
      }
    }
    // ----------------------------------------

    // Create a local message object for caching
    final localMessage = ChatMessage(
      id: msgRef.id,
      senderId: senderId,
      text: trimmed,
      timestamp: DateTime.now(),
      isRead: false,
      isDelivered: true,
      messageType: messageType,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToSenderName: replyToSenderName,
    );

    try {
      final batch = _firestore.batch();

      // Add message to Firestore
      batch.set(msgRef, {
        'senderId': senderId,
        'text': trimmed,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDelivered': true,
        'messageType': messageType.toString().split('.').last,
        'replyToId': replyToId,
        'replyToText': replyToText,
        'replyToSenderName': replyToSenderName,
      });

      // Update chat metadata + increment receiver unread count
      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'lastMessage': trimmed,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCount.$receiverId': FieldValue.increment(1),
      });

      await batch.commit();

      // Cache locally after successful send
      await _localDb.insertMessage(localMessage, chatId);
    } catch (e) {
      debugPrint('Error sending message: $e');
      // Still cache locally even if Firestore fails
      await _localDb.insertMessage(localMessage, chatId);
      rethrow;
    }
  }

  /// Send a message with media (image, voice, GIF, etc.)
  Future<void> sendMediaMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
    required MessageType messageType,
    required String mediaUrl,
    int? voiceDuration,
    String? replyToId,
    String? replyToText,
    String? replyToSenderName,
  }) async {
    final msgRef =
        _firestore.collection('chats').doc(chatId).collection('messages').doc();

    // --- Daily Free Message Limit Check ---
    final senderRef = _firestore.collection('users').doc(senderId);
    final senderDoc = await senderRef.get();
    if (senderDoc.exists) {
      final data = senderDoc.data() as Map<String, dynamic>;
      final bool isPremium = data['isPremium'] == true;
      
      if (!isPremium) {
        final String today = DateTime.now().toIso8601String().split('T')[0];
        final String? lastReset = data['lastMessageResetDate']?.toString();
        int dailyCount = (data['dailyMessageCount'] as num?)?.toInt() ?? 0;
        
        if (lastReset != today) {
          dailyCount = 0;
        }
        
        // We no longer throw an exception here. 
        // The client-side handles charging sparks after the 5 free messages are used up.
        
        await senderRef.update({
          'dailyMessageCount': dailyCount + 1,
          'lastMessageResetDate': today,
        });
      }
    }
    // ----------------------------------------

    // Create a local message object for caching
    final localMessage = ChatMessage(
      id: msgRef.id,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
      isRead: false,
      isDelivered: true,
      messageType: messageType,
      mediaUrl: mediaUrl,
      voiceDuration: voiceDuration,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToSenderName: replyToSenderName,
    );

    try {
      final batch = _firestore.batch();

      // Add message to Firestore
      batch.set(msgRef, {
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDelivered': true,
        'messageType': messageType.toString().split('.').last,
        'mediaUrl': mediaUrl,
        'voiceDuration': voiceDuration,
        'replyToId': replyToId,
        'replyToText': replyToText,
        'replyToSenderName': replyToSenderName,
      });

      // Update chat metadata
      final displayText = messageType == MessageType.image
          ? '📷 Image'
          : messageType == MessageType.voice
              ? '🎤 Voice message'
              : messageType == MessageType.gif
                  ? '🎬 GIF'
                  : text;

      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'lastMessage': displayText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCount.$receiverId': FieldValue.increment(1),
      });

      await batch.commit();

      // Cache locally after successful send
      await _localDb.insertMessage(localMessage, chatId);
    } catch (e) {
      debugPrint('Error sending media message: $e');
      // Still cache locally even if Firestore fails
      await _localDb.insertMessage(localMessage, chatId);
      rethrow;
    }
  }

  /// Sends a meetup request message
  Future<void> sendMeetupMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String meetupId,
    required String text, // e.g. "Proposed a meetup on May 20, 2024 at 18:00"
  }) async {
    final msgRef =
        _firestore.collection('chats').doc(chatId).collection('messages').doc();

    // --- Daily Free Message Limit Check ---
    final senderRef = _firestore.collection('users').doc(senderId);
    final senderDoc = await senderRef.get();
    if (senderDoc.exists) {
      final data = senderDoc.data() as Map<String, dynamic>;
      final bool isPremium = data['isPremium'] == true;
      
      if (!isPremium) {
        final String today = DateTime.now().toIso8601String().split('T')[0];
        final String? lastReset = data['lastMessageResetDate']?.toString();
        int dailyCount = (data['dailyMessageCount'] as num?)?.toInt() ?? 0;
        
        if (lastReset != today) {
          dailyCount = 0;
        }
        
        // We no longer throw an exception here. 
        // The client-side handles charging sparks after the 5 free messages are used up.
        
        await senderRef.update({
          'dailyMessageCount': dailyCount + 1,
          'lastMessageResetDate': today,
        });
      }
    }
    // ----------------------------------------

    final localMessage = ChatMessage(
      id: msgRef.id,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
      isRead: false,
      isDelivered: true,
      messageType: MessageType.meetup,
      mediaUrl: meetupId, // Use mediaUrl to store meetupId
    );

    try {
      final batch = _firestore.batch();

      batch.set(msgRef, {
        'senderId': senderId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDelivered': true,
        'messageType': MessageType.meetup.toString().split('.').last,
        'mediaUrl': meetupId,
      });

      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'lastMessage': '📅 Meetup Proposal',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCount.$receiverId': FieldValue.increment(1),
      });

      await batch.commit();
      await _localDb.insertMessage(localMessage, chatId);
    } catch (e) {
      debugPrint('Error sending meetup message: $e');
      await _localDb.insertMessage(localMessage, chatId);
      rethrow;
    }
  }

  /// Sends a Super Request (priority chat) for 20 sparks
  Future<void> sendSuperRequest({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();

    // 1. Mark chat as Super Request
    batch.update(chatRef, {
      'isSuperRequest': true,
      'lastMessage': '🔥 Super Request: $text',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    // 2. Add the message
    batch.set(msgRef, {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'isDelivered': true,
      'messageType': 'text',
      'isSuperRequest': true, // Optional: flag the message too
    });

    await batch.commit();

    // Cache locally
    final localChat = await _localDb.getChatById(chatId);
    if (localChat != null) {
      await _localDb.insertOrUpdateChat(Chat(
        id: localChat.id,
        participants: localChat.participants,
        lastMessage: '🔥 Super Request: $text',
        lastMessageTime: DateTime.now(),
        lastMessageSenderId: senderId,
        unreadCount: localChat.unreadCount,
        isSuperRequest: true,
      ));
    }
  }

  /// Sends a gift in chat, deducting sparks from sender
  Future<void> sendGift({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String giftType,
    required int giftValue,
  }) async {
    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc();
    final senderRef = _firestore.collection('users').doc(senderId);
    final receiverRef = _firestore.collection('users').doc(receiverId);

    // 1. Deduct sparks from sender
    batch.update(senderRef, {
      'credits': FieldValue.increment(-giftValue),
    });

    // 2. Add sparks to receiver
    batch.update(receiverRef, {
      'credits': FieldValue.increment(giftValue),
    });

    // 3. Add gift message
    final text = 'sent you a $giftType!';
    batch.set(msgRef, {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'isDelivered': true,
      'messageType': 'gift',
      'giftType': giftType,
      'giftValue': giftValue,
    });

    // 3. Update chat meta
    batch.update(chatRef, {
      'lastMessage': '🎁 $giftType',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();

    // Cache locally
    final localMessage = ChatMessage(
      id: msgRef.id,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
      messageType: MessageType.gift,
      giftType: giftType,
      giftValue: giftValue,
    );
    await _localDb.insertMessage(localMessage, chatId);
  }

  /// Upload a file to PHP backend server
  Future<String> uploadFile({
    required String filePath,
    required String fileType, // 'images', 'voice', 'gifs'
    required String chatId,
    required String userId,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('File not found: $filePath');
      }

      // Safe extension extraction
      String fileExtension = '';
      if (filePath.contains('.')) {
        fileExtension = filePath.split('.').last.toLowerCase();
      }

      // Fallback to jpg if the extension is missing or invalid for web standards
      const validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      if (fileExtension.isEmpty || !validExtensions.contains(fileExtension)) {
        fileExtension = 'jpg';
      }

      // Determine proper mime subtype
      final mimeSubtype = fileExtension == 'jpg' ? 'jpeg' : fileExtension;

      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(_uploadEndpoint));

      // Add file to request
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename:
              '${DateTime.now().millisecondsSinceEpoch}_$userId.$fileExtension',
          contentType: MediaType('image', mimeSubtype),
        ),
      );

      // Add metadata
      request.fields['chatId'] = chatId;
      request.fields['userId'] = userId;
      request.fields['fileType'] = fileType;

      // Send request
      var streamResponse =
          await request.send().timeout(const Duration(seconds: 60));
      var response = await http.Response.fromStream(streamResponse);

      if (response.statusCode != 200) {
        throw Exception(
            'Upload failed with status ${response.statusCode}: ${response.body}');
      }

      // Parse response
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] == true && data['file_url'] != null) {
        String url = data['file_url'] as String;
        // Fix for backend script upload2.php omitting the app directory
        if (url.contains('unimarket-mw.com/uploads/')) {
          url = url.replaceFirst('unimarket-mw.com/uploads/',
              'unimarket-mw.com/snellum/api/uploads/');
        }
        return url;
      } else {
        throw Exception(data['error'] ?? 'Unknown error');
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
      rethrow;
    }
  }

  /// Stream of messages for a chat (real-time with local fallback)
  Stream<List<ChatMessage>> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      final messages = snap.docs.map(ChatMessage.fromDoc).toList();

      // Sort in Dart to include messages with null timestamps (pending server sync)
      // null timestamps are handled by ChatMessage.fromDoc using DateTime.now()
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Cache messages to local DB
      _localDb.insertMessages(messages, chatId);
      return messages;
    }).handleError((error) {
      debugPrint('Error in getMessagesStream: $error');
      // Return cached messages on error
      return _localDb.getMessagesForChat(chatId);
    });
  }

  /// Get messages since a specific timestamp (for incremental sync)
  Future<List<ChatMessage>> getMessagesSinceTimestamp(
    String chatId,
    DateTime? sinceTimestamp,
  ) async {
    try {
      final query = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false);

      final targetQuery = sinceTimestamp != null
          ? query.where('timestamp',
              isGreaterThan: Timestamp.fromDate(sinceTimestamp))
          : query;

      final snap = await targetQuery.get();
      final messages = snap.docs.map(ChatMessage.fromDoc).toList();

      // Cache new messages
      if (messages.isNotEmpty) {
        await _localDb.insertMessages(messages, chatId);
      }

      return messages;
    } catch (e) {
      debugPrint('Error fetching messages since timestamp: $e');
      return [];
    }
  }

  /// Smart stream that combines cached + new messages
  Stream<List<ChatMessage>> getMessagesStreamSmart(String chatId) async* {
    try {
      // 1. First, yield cached messages from local DB for instant UX
      final cachedMessages = await _localDb.getMessagesForChat(chatId);
      if (cachedMessages.isNotEmpty) {
        yield cachedMessages;
      }

      // 2. Stream all messages from Firestore for this chat.
      // We don't filter by timestamp here to avoid missing updates to old messages
      // and to ensure pending writes (null timestamp) are included.
      yield* _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .snapshots(includeMetadataChanges: true)
          .map((snap) {
        final firestoreMessages = snap.docs.map(ChatMessage.fromDoc).toList();

        // Cache new messages
        if (firestoreMessages.isNotEmpty) {
          _localDb.insertMessages(firestoreMessages, chatId);
        }

        // Merge with cached messages and deduplicate by ID
        final Map<String, ChatMessage> messageMap = {};
        for (var msg in cachedMessages) {
          messageMap[msg.id] = msg;
        }
        for (var msg in firestoreMessages) {
          messageMap[msg.id] = msg;
        }

        final combinedMessages = messageMap.values.toList();
        combinedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        return combinedMessages;
      }).handleError((error) {
        debugPrint('Error in smart message stream: $error');
        return cachedMessages;
      });
    } catch (e) {
      debugPrint('Error in initial message load: $e');
      yield [];
    }
  }

  /// Upload a voice note (.m4a) to PHP backend server
  Future<String> uploadVoiceFile({
    required String filePath,
    required String chatId,
    required String userId,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('Voice file not found: $filePath');
      }

      var request = http.MultipartRequest('POST', Uri.parse(_uploadEndpoint));

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: '${DateTime.now().millisecondsSinceEpoch}_$userId.m4a',
          contentType: MediaType('audio', 'm4a'),
        ),
      );

      request.fields['chatId'] = chatId;
      request.fields['userId'] = userId;
      request.fields['fileType'] = 'voice';

      var streamResponse =
          await request.send().timeout(const Duration(seconds: 60));
      var response = await http.Response.fromStream(streamResponse);

      if (response.statusCode != 200) {
        throw Exception(
            'Upload failed with status ${response.statusCode}: ${response.body}');
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] == true && data['file_url'] != null) {
        String url = data['file_url'] as String;
        if (url.contains('unimarket-mw.com/uploads/')) {
          url = url.replaceFirst('unimarket-mw.com/uploads/',
              'unimarket-mw.com/snellum/api/uploads/');
        }
        return url;
      } else {
        throw Exception(data['error'] ?? 'Unknown error');
      }
    } catch (e) {
      debugPrint('Error uploading voice file: $e');
      rethrow;
    }
  }

  /// Stream of all chats for a user
  Stream<List<Chat>> getChatsStream(String uid) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
      final chats = snap.docs.map(Chat.fromDoc).toList();
      // Cache chats to local DB
      for (final chat in chats) {
        _localDb.insertOrUpdateChat(chat);
      }
      // Sort on client side: Super Requests first, then by time
      chats.sort((a, b) {
        if (a.isSuperRequest && !b.isSuperRequest) return -1;
        if (!a.isSuperRequest && b.isSuperRequest) return 1;

        final aTime =
            a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return chats;
    }).handleError((error) {
      debugPrint('Error in getChatsStream: $error');
      // Return cached chats on error
      return _localDb.getChatsForUser(uid);
    });
  }

  /// Mark message as read
  Future<void> markMessageAsRead(
    String chatId,
    String messageId,
  ) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isRead': true,
      });
      // Also update local DB
      await _localDb.updateMessageReadStatus(messageId, true);
    } catch (e) {
      debugPrint('Error marking message as read: $e');
      // Still update local DB even if Firestore fails
      await _localDb.updateMessageReadStatus(messageId, true);
    }
  }

  /// Mark all messages from a sender as read
  Future<void> markAllMessagesAsRead(
    String chatId,
    String senderId,
    String myUid,
  ) async {
    try {
      final messagesRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .where('isRead', isEqualTo: false);

      final snapshot = await messagesRef.get();
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      // Update unread count
      batch.update(
        _firestore.collection('chats').doc(chatId),
        {
          'unreadCount.$myUid': 0,
        },
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all messages as read: $e');
    }
  }

  /// Set user online status
  Future<void> setUserOnline(String uid, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(uid).set(
        {
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error setting user online status: $e');
    }
  }

  /// Stream user's online status
  Stream<bool> getUserOnlineStatus(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return false;
      final data = snap.data();
      if (data == null) return false;

      final isOnlineFlag = (data['isOnline'] as bool?) ?? false;
      if (!isOnlineFlag) return false;

      // Check lastSeen timestamp freshness to prevent stale online status
      final lastSeenRaw = data['lastSeen'];
      if (lastSeenRaw is Timestamp) {
        final lastSeen = lastSeenRaw.toDate();
        final diffInSeconds = DateTime.now().difference(lastSeen).inSeconds;
        // If lastSeen was over 2 minutes (120 seconds) ago, treat as offline
        if (diffInSeconds > 120) {
          return false;
        }
      }

      return true;
    }).handleError((error) {
      debugPrint('Error getting user online status: $error');
      return false;
    });
  }

  /// Marks all messages as read when opening a chat
  Future<void> markAsRead(String chatId, String myUid) async {
    try {
      final chatRef = _firestore.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();

      if (chatDoc.exists) {
        final data = chatDoc.data()!;
        final lastSenderId = data['lastMessageSenderId'] as String?;
        final isSuper = data['isSuperRequest'] as bool? ?? false;

        Map<String, dynamic> updateData = {
          'unreadCount.$myUid': 0,
        };

        // If the viewer is the recipient and it's a super request, clear the flag
        if (isSuper && lastSenderId != myUid) {
          updateData['isSuperRequest'] = false;
        }

        await chatRef.update(updateData);
      }

      // Mark all unread messages as read
      final messagesRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false);

      final snapshot = await messagesRef.get();
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  /// Sets typing status for the current user in a chat
  Future<void> setTypingStatus(String chatId, String userId, bool isTyping) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'typingStatus.$userId': isTyping,
      });
    } catch (e) {
      debugPrint('Error updating typing status: $e');
    }
  }

  /// Streams the typing status of the other user in a chat
  Stream<bool> getTypingStream(String chatId, String otherUserId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((snap) {
      if (!snap.exists) return false;
      final data = snap.data();
      if (data == null) return false;
      final typingMap = data['typingStatus'] as Map<String, dynamic>?;
      return typingMap?[otherUserId] == true;
    }).handleError((error) {
      debugPrint('Error in getTypingStream: $error');
      return false;
    });
  }

  /// Get total unread message count for a user
  Stream<int> getUnreadMessageCountStream(String uid) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
      int totalUnread = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final unreadCount = data['unreadCount'] as Map<dynamic, dynamic>?;
        if (unreadCount != null) {
          final userUnread = unreadCount[uid];
          if (userUnread is int) {
            totalUnread += userUnread;
          }
        }
      }
      return totalUnread;
    }).handleError((error) {
      debugPrint('Error getting unread count: $error');
      return 0;
    });
  }

  /// Deletes all messages in a chat and resets metadata
  Future<void> clearChat(String chatId) async {
    try {
      // Delete messages in batches of 500 (Firestore limit)
      while (true) {
        final snap = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .limit(500)
            .get();

        if (snap.docs.isEmpty) break;

        final batch = _firestore.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // Reset chat metadata
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
      });

      // Clear local SQLite cache
      await _localDb.deleteMessagesForChat(chatId);
    } catch (e) {
      debugPrint('Error clearing chat: $e');
      rethrow;
    }
  }

  /// Edits a message's text
  Future<void> editMessage(
      String chatId, String messageId, String newText) async {
    try {
      final trimmed = newText.trim();
      if (trimmed.isEmpty) return;

      final batch = _firestore.batch();
      final msgRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      batch.update(msgRef, {
        'text': trimmed,
        'isEdited': true,
      });

      // Update chat meta if this was the last message
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (chatDoc.exists) {
        // We can't easily know if this EXACT message was the last one without checking id
        // but checking the timestamp proximity is a good heuristic if we don't have lastMsgId in chat meta.
        // For now, let's just update lastMessage if it matches the previous text or just always update if it's the sender
        // A better way would be to check the actual last message in the collection.

        final lastMsgs = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (lastMsgs.docs.isNotEmpty && lastMsgs.docs.first.id == messageId) {
          batch.update(_firestore.collection('chats').doc(chatId), {
            'lastMessage': trimmed,
          });
        }
      }

      await batch.commit();
      await _localDb.updateMessageTextOrStatus(messageId,
          text: trimmed, isEdited: true);
    } catch (e) {
      debugPrint('Error editing message: $e');
      rethrow;
    }
  }

  /// Soft deletes a message
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      final batch = _firestore.batch();
      final msgRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      batch.update(msgRef, {
        'text': 'This message was deleted',
        'isDeleted': true,
        'mediaUrl': null,
        'voiceDuration': null,
      });

      // Update chat meta if this was the last message
      final lastMsgs = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (lastMsgs.docs.isNotEmpty && lastMsgs.docs.first.id == messageId) {
        batch.update(_firestore.collection('chats').doc(chatId), {
          'lastMessage': 'This message was deleted',
        });
      }

      await batch.commit();
      await _localDb.updateMessageTextOrStatus(messageId,
          text: 'This message was deleted', isDeleted: true);
    } catch (e) {
      debugPrint('Error deleting message: $e');
      rethrow;
    }
  }

  /// Stream of a single chat document
  Stream<Chat?> getChatStream(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return Chat.fromDoc(snap);
    });
  }

  /// Accept a message request
  Future<void> acceptRequest(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'requestStatus': 'accepted',
      });
    } catch (e) {
      debugPrint('Error accepting request: $e');
    }
  }

  /// Decline a message request
  Future<void> declineRequest(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'requestStatus': 'declined',
      });
    } catch (e) {
      debugPrint('Error declining request: $e');
    }
  }
}
