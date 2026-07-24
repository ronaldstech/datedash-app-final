import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/live_stream_model.dart';
import 'profile_service.dart';
import 'notification_service.dart';

class LiveStreamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProfileService _profileService = ProfileService();
  final NotificationService _notificationService = NotificationService();

  CollectionReference get _liveStreamsCollections =>
      _firestore.collection('live_streams');

  /// Starts a new live stream
  Future<String> startStream({
    required String streamId,
    required String userId,
    required String userName,
    required String userPhoto,
    required String title,
  }) async {
    // 1. End any existing active streams for this user
    final existingStreams = await _liveStreamsCollections
        .where('broadcasterId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();

    for (var doc in existingStreams.docs) {
      await endStream(doc.id);
    }

    // 2. Start the new stream
    final stream = LiveStream(
      id: streamId,
      broadcasterId: userId,
      broadcasterName: userName,
      broadcasterPhoto: userPhoto,
      title: title,
      startedAt: DateTime.now(),
    );

    await _liveStreamsCollections.doc(streamId).set(stream.toMap());
    return streamId;
  }

  /// Ends an active live stream
  Future<void> endStream(String streamId) async {
    await _liveStreamsCollections.doc(streamId).update({'status': 'ended'});
    // We can delete it later or keep it for history, but for now let's just delete
    await _liveStreamsCollections.doc(streamId).delete();
  }

  /// Joins a live stream (increments viewer count)
  Future<void> joinStream(String streamId) async {
    await _liveStreamsCollections.doc(streamId).update({
      'viewerCount': FieldValue.increment(1),
    });
  }

  /// Leaves a live stream (decrements viewer count)
  Future<void> leaveStream(String streamId) async {
    await _liveStreamsCollections.doc(streamId).update({
      'viewerCount': FieldValue.increment(-1),
    });
  }

  /// Returns a stream of active live sessions
  Stream<List<LiveStream>> getActiveStreamsStream() {
    return _liveStreamsCollections
        .where('status', isEqualTo: 'active')
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return LiveStream.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        });
  }

  /// Sends a chat message or gift in a live stream
  Future<void> sendMessage({
    required String streamId,
    required String senderId,
    required String senderName,
    required String senderPhoto,
    required String message,
    String? giftType,
    int? giftValue,
  }) async {
    final chatMessage = LiveChatMessage(
      id: '',
      senderId: senderId,
      senderName: senderName,
      senderPhoto: senderPhoto,
      message: message,
      giftType: giftType,
      giftValue: giftValue,
      timestamp: DateTime.now(),
    );

    await _liveStreamsCollections
        .doc(streamId)
        .collection('messages')
        .add(chatMessage.toMap());

    if (giftType != null && giftValue != null) {
      // Handle gift transaction
      await _profileService.deductCredits(senderId, giftValue);

      // Get broadcaster ID
      final streamDoc = await _liveStreamsCollections.doc(streamId).get();
      if (streamDoc.exists) {
        final broadcasterId = streamDoc['broadcasterId'];
        await _profileService.addCredits(broadcasterId, giftValue);

        // Notify broadcaster
        await _notificationService.sendNotification(
          recipientId: broadcasterId,
          senderId: senderId,
          senderName: senderName,
          type: 'gift',
          message:
              'Sent you a $giftType worth $giftValue sparks during your live!',
        );
      }
    }
  }

  /// Returns a stream of messages for a specific live session
  Stream<List<LiveChatMessage>> getMessagesStream(String streamId) {
    return _liveStreamsCollections
        .doc(streamId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return LiveChatMessage.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  /// Invites a guest to join the live stream
  Future<void> inviteGuest({
    required String streamId,
    required String hostId,
    required String hostName,
    required String guestId,
    required String guestName,
    required String guestPhoto,
  }) async {
    await _liveStreamsCollections.doc(streamId).update({
      'guestId': guestId,
      'guestName': guestName,
      'guestPhoto': guestPhoto,
      'guestStatus': 'invited',
    });

    await _notificationService.sendNotification(
      recipientId: guestId,
      senderId: hostId,
      senderName: hostName,
      type: 'live_invite',
      message: streamId,
    );
  }

  /// Accepts a guest invitation
  Future<void> acceptInvite(String streamId) async {
    await _liveStreamsCollections.doc(streamId).update({
      'guestStatus': 'joined',
    });
  }

  /// Declines a guest invitation
  Future<void> declineInvite(String streamId) async {
    await _liveStreamsCollections.doc(streamId).update({
      'guestStatus': 'declined',
      'guestId': FieldValue.delete(),
      'guestName': FieldValue.delete(),
      'guestPhoto': FieldValue.delete(),
    });
  }

  /// Removes a guest from the stream (either kicked by host or left)
  Future<void> removeGuest(String streamId) async {
    await _liveStreamsCollections.doc(streamId).update({
      'guestStatus': FieldValue.delete(),
      'guestId': FieldValue.delete(),
      'guestName': FieldValue.delete(),
      'guestPhoto': FieldValue.delete(),
    });
  }
}
