import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Initialize notifications (handlers only — permission is requested via onboarding modal)
  Future<void> initialize() async {
    try {
      // 1. Setup background messaging handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Foreground message listener (just log or notify custom wrapper)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Got a message whilst in the foreground!');
          print('Message data: ${message.data}');
        }
        if (message.notification != null) {
          if (kDebugMode) {
            print('Message also contained a notification: ${message.notification}');
          }
        }
      });
    } catch (e) {
      debugPrint('PushNotificationService Error during initialization: $e');
    }
  }

  // Update FCM token in Firestore for current user
  Future<void> updateTokenInFirestore(String uid) async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': token,
        });
        if (kDebugMode) {
          print('FCM Token successfully saved for user $uid: $token');
        }
      }
    } catch (e) {
      debugPrint('Error updating FCM Token in Firestore: $e');
    }
  }
}

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Make sure firebase is initialized before handling background notifications
  // (FCM package takes care of this on background isolate but good to know)
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
  }
}
