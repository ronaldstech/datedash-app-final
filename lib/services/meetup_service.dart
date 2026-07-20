import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/meetup_model.dart';
import 'notification_service.dart';

class MeetupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _meetupsCollection => _firestore.collection('meetups');

  /// Creates a new meetup request
  Future<void> createMeetup(MeetupModel meetup, {String? senderName}) async {
    try {
      final docRef = await _meetupsCollection.add(meetup.toMap());
      
      // Notify the receiver
      await NotificationService().sendNotification(
        recipientId: meetup.receiverId,
        senderId: meetup.senderId,
        senderName: senderName ?? 'Someone',
        type: 'meetup_request',
      );
      
      debugPrint('MeetupService: Created meetup ${docRef.id}');
    } catch (e) {
      debugPrint('Error creating meetup: $e');
      rethrow;
    }
  }

  /// Updates meetup status (accepted, rejected, cancelled)
  Future<void> updateMeetupStatus(String meetupId, MeetupStatus status, {required String currentUserId, required String otherUserId, String? senderName}) async {
    try {
      await _meetupsCollection.doc(meetupId).update({
        'status': status.toString().split('.').last,
      });

      // Notify the other user about the status change
      await NotificationService().sendNotification(
        recipientId: otherUserId,
        senderId: currentUserId,
        senderName: senderName ?? 'Someone',
        type: 'meetup_${status.toString().split('.').last}',
      );

      debugPrint('MeetupService: Updated meetup $meetupId to $status');
    } catch (e) {
      debugPrint('Error updating meetup status: $e');
      rethrow;
    }
  }

  /// Returns a stream of meetups for a specific user (either as sender or receiver)
  Stream<List<MeetupModel>> getUserMeetupsStream(String userId) {
    return _firestore
        .collection('meetups')
        .where(Filter.or(
          Filter('senderId', isEqualTo: userId),
          Filter('receiverId', isEqualTo: userId),
        ))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MeetupModel.fromDoc(doc)).toList();
    });
  }

  /// Returns a stream of pending received meetups for a user
  Stream<List<MeetupModel>> getPendingReceivedMeetupsStream(String userId) {
    return _meetupsCollection
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MeetupModel.fromDoc(doc)).toList();
    });
  }

  /// Checks if there's a pending meetup between two users
  Future<MeetupModel?> getPendingMeetup(String uid1, String uid2) async {
    try {
      final snapshot = await _meetupsCollection
          .where('status', isEqualTo: 'pending')
          .get();

      final doc = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final senderId = data['senderId'];
        final receiverId = data['receiverId'];
        return (senderId == uid1 && receiverId == uid2) || (senderId == uid2 && receiverId == uid1);
      }).firstOrNull;

      if (doc != null) {
        return MeetupModel.fromDoc(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error checking pending meetup: $e');
      return null;
    }
  }
}
