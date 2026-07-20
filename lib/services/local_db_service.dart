import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_model.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  static Database? _database;

  LocalDbService._internal();

  factory LocalDbService() {
    return _instance;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'datedash.db');

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createTables,
      onUpgrade: _upgradeDb,
    );
  }

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try { await db.execute('ALTER TABLE messages ADD COLUMN messageType TEXT DEFAULT "text"'); } catch (_) {}
      try { await db.execute('ALTER TABLE messages ADD COLUMN mediaUrl TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE messages ADD COLUMN voiceDuration INTEGER'); } catch (_) {}
    }
    if (oldVersion < 3) {
      try { await db.execute('ALTER TABLE messages ADD COLUMN isEdited INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE messages ADD COLUMN isDeleted INTEGER DEFAULT 0'); } catch (_) {}
    }
    if (oldVersion < 4) {
      try { await db.execute('ALTER TABLE chats ADD COLUMN isSuperRequest INTEGER DEFAULT 0'); } catch (_) {}
    }
    if (oldVersion < 6) {
      try { await db.execute('ALTER TABLE messages ADD COLUMN replyToId TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE messages ADD COLUMN replyToText TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE messages ADD COLUMN replyToSenderName TEXT'); } catch (_) {}
    }
  }

  Future<void> _createTables(Database db, int version) async {
    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        chatId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        text TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        isRead INTEGER NOT NULL DEFAULT 0,
        isDelivered INTEGER NOT NULL DEFAULT 1,
        messageType TEXT NOT NULL DEFAULT 'text',
        mediaUrl TEXT,
        voiceDuration INTEGER,
        isEdited INTEGER NOT NULL DEFAULT 0,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        giftType TEXT,
        giftValue INTEGER,
        replyToId TEXT,
        replyToText TEXT,
        replyToSenderName TEXT,
        createdAt INTEGER NOT NULL
      )
    ''');

    // Chats table
    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        participants TEXT NOT NULL,
        lastMessage TEXT,
        lastMessageTime INTEGER,
        lastMessageSenderId TEXT,
        unreadCount TEXT,
        isSuperRequest INTEGER DEFAULT 0,
        createdAt INTEGER
      )
    ''');

    // Create indices for faster queries
    await db.execute(
      'CREATE INDEX idx_messages_chatId ON messages(chatId)',
    );
    await db.execute(
      'CREATE INDEX idx_messages_timestamp ON messages(timestamp)',
    );
    await db.execute(
      'CREATE INDEX idx_chats_createdAt ON chats(createdAt)',
    );
  }

  // ─── MESSAGE OPERATIONS ───
  Future<void> insertMessage(ChatMessage msg, String chatId) async {
    final db = await database;
    await db.insert(
      'messages',
      {
        'id': msg.id,
        'chatId': chatId,
        'senderId': msg.senderId,
        'text': msg.text,
        'timestamp': msg.timestamp.millisecondsSinceEpoch,
        'isRead': msg.isRead ? 1 : 0,
        'isDelivered': msg.isDelivered ? 1 : 0,
        'messageType': msg.messageType.toString().split('.').last,
        'mediaUrl': msg.mediaUrl,
        'voiceDuration': msg.voiceDuration,
        'isEdited': msg.isEdited ? 1 : 0,
        'isDeleted': msg.isDeleted ? 1 : 0,
        'giftType': msg.giftType,
        'giftValue': msg.giftValue,
        'replyToId': msg.replyToId,
        'replyToText': msg.replyToText,
        'replyToSenderName': msg.replyToSenderName,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertMessages(List<ChatMessage> messages, String chatId) async {
    final db = await database;
    for (final msg in messages) {
      await db.insert(
        'messages',
        {
          'id': msg.id,
          'chatId': chatId,
          'senderId': msg.senderId,
          'text': msg.text,
          'timestamp': msg.timestamp.millisecondsSinceEpoch,
          'isRead': msg.isRead ? 1 : 0,
          'isDelivered': msg.isDelivered ? 1 : 0,
          'messageType': msg.messageType.toString().split('.').last,
          'mediaUrl': msg.mediaUrl,
          'voiceDuration': msg.voiceDuration,
          'isEdited': msg.isEdited ? 1 : 0,
          'isDeleted': msg.isDeleted ? 1 : 0,
          'giftType': msg.giftType,
          'giftValue': msg.giftValue,
          'replyToId': msg.replyToId,
          'replyToText': msg.replyToText,
          'replyToSenderName': msg.replyToSenderName,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  MessageType _parseLocalMessageType(String? type) {
    if (type == 'image') return MessageType.image;
    if (type == 'voice') return MessageType.voice;
    if (type == 'gif') return MessageType.gif;
    if (type == 'call') return MessageType.call;
    if (type == 'sticker') return MessageType.sticker;
    if (type == 'gift') return MessageType.gift;
    return MessageType.text;
  }

  Future<List<ChatMessage>> getMessagesForChat(String chatId) async {
    final db = await database;
    final result = await db.query(
      'messages',
      where: 'chatId = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );

    return result
        .map((row) => ChatMessage(
              id: row['id'] as String,
              senderId: row['senderId'] as String,
              text: row['text'] as String,
              timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
              isRead: (row['isRead'] as int) == 1,
              isDelivered: (row['isDelivered'] as int) == 1,
              messageType: _parseLocalMessageType(row['messageType'] as String?),
              mediaUrl: row['mediaUrl'] as String?,
              voiceDuration: row['voiceDuration'] as int?,
              isEdited: (row['isEdited'] as int) == 1,
              isDeleted: (row['isDeleted'] as int) == 1,
              giftType: row['giftType'] as String?,
              giftValue: row['giftValue'] as int?,
              replyToId: row['replyToId'] as String?,
              replyToText: row['replyToText'] as String?,
              replyToSenderName: row['replyToSenderName'] as String?,
            ))
        .toList();
  }

  Future<void> updateMessageReadStatus(String msgId, bool isRead) async {
    final db = await database;
    await db.update(
      'messages',
      {'isRead': isRead ? 1 : 0},
      where: 'id = ?',
      whereArgs: [msgId],
    );
  }

  Future<void> deleteMessagesForChat(String chatId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'chatId = ?',
      whereArgs: [chatId],
    );
  }

  Future<void> updateMessageTextOrStatus(String msgId, {String? text, bool? isEdited, bool? isDeleted}) async {
    final db = await database;
    final Map<String, dynamic> updates = {};
    if (text != null) updates['text'] = text;
    if (isEdited != null) updates['isEdited'] = isEdited ? 1 : 0;
    if (isDeleted != null) updates['isDeleted'] = isDeleted ? 1 : 0;
    
    if (updates.isNotEmpty) {
      await db.update(
        'messages',
        updates,
        where: 'id = ?',
        whereArgs: [msgId],
      );
    }
  }

  // ─── CHAT OPERATIONS ───
  Future<void> insertOrUpdateChat(Chat chat) async {
    final db = await database;
    await db.insert(
      'chats',
      {
        'id': chat.id,
        'participants': chat.participants.join(','),
        'lastMessage': chat.lastMessage,
        'lastMessageTime': chat.lastMessageTime?.millisecondsSinceEpoch,
        'lastMessageSenderId': chat.lastMessageSenderId,
        'unreadCount': _encodeUnreadCount(chat.unreadCount),
        'isSuperRequest': chat.isSuperRequest ? 1 : 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Chat>> getChatsForUser(String uid) async {
    final db = await database;
    final result = await db.query(
      'chats',
      orderBy: 'lastMessageTime DESC',
    );

    return result
        .map((row) {
          final participants = (row['participants'] as String?)?.split(',') ?? [];
          // Filter chats where the user is a participant
          if (!participants.contains(uid)) return null;

          return Chat(
            id: row['id'] as String,
            participants: participants,
            lastMessage: row['lastMessage'] as String? ?? '',
            lastMessageTime: row['lastMessageTime'] != null
                ? DateTime.fromMillisecondsSinceEpoch(row['lastMessageTime'] as int)
                : null,
            lastMessageSenderId: row['lastMessageSenderId'] as String? ?? '',
            unreadCount: _decodeUnreadCount(row['unreadCount'] as String?),
            isSuperRequest: (row['isSuperRequest'] as int? ?? 0) == 1,
          );
        })
        .whereType<Chat>()
        .toList();
  }

  Future<Chat?> getChatById(String chatId) async {
    final db = await database;
    final result = await db.query(
      'chats',
      where: 'id = ?',
      whereArgs: [chatId],
    );

    if (result.isEmpty) return null;

    final row = result.first;
    return Chat(
      id: row['id'] as String,
      participants: (row['participants'] as String?)?.split(',') ?? [],
      lastMessage: row['lastMessage'] as String? ?? '',
      lastMessageTime: row['lastMessageTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['lastMessageTime'] as int)
          : null,
      lastMessageSenderId: row['lastMessageSenderId'] as String? ?? '',
      unreadCount: _decodeUnreadCount(row['unreadCount'] as String?),
      isSuperRequest: (row['isSuperRequest'] as int? ?? 0) == 1,
    );
  }

  Future<void> deleteAllChats() async {
    final db = await database;
    await db.delete('chats');
    await db.delete('messages');
  }

  // ─── HELPER METHODS ───
  String _encodeUnreadCount(Map<String, int> unreadCount) {
    return unreadCount.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  Map<String, int> _decodeUnreadCount(String? encoded) {
    if (encoded == null || encoded.isEmpty) return {};
    final map = <String, int>{};
    for (final pair in encoded.split('|')) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        map[parts[0]] = int.tryParse(parts[1]) ?? 0;
      }
    }
    return map;
  }

  // ─── DATABASE MANAGEMENT ───
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('chats');
  }

  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }
}
