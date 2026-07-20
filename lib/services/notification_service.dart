import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection Reference
  CollectionReference get _notificationsCollection =>
      _firestore.collection('notifications');

  /// Sends a new notification to a user
  Future<void> sendNotification({
    required String recipientId,
    required String senderId,
    required String senderName,
    required String type,
    String? message,
  }) async {
    // Don't notify yourself
    if (recipientId == senderId) return;

    try {
      debugPrint('Attempting to send notification: $type from $senderName to $recipientId');
      
      await _notificationsCollection.add({
        'recipientId': recipientId,
        'senderId': senderId,
        'senderName': senderName,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'message': message,
      });
      
      debugPrint('Notification successfully added to Firestore');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Returns a stream of notifications for a user
  Stream<List<DatedashNotification>> getNotificationsStream(String userId) {
    return _notificationsCollection
        .where('recipientId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final List<DatedashNotification> notifications = snapshot.docs.map((doc) {
        return DatedashNotification.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
      
      // Manually sort in memory if needed, or just let them be for now
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return notifications;
    });
  }

  /// Returns a stream of unread notification count
  Stream<int> getUnreadCountStream(String userId) {
    return _notificationsCollection
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Marks a specific notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Marks all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      final unread = await _notificationsCollection
          .where('recipientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unread.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      rethrow;
    }
  }
}
