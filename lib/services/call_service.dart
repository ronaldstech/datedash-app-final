import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Listen for incoming calls directed to the current user
  Stream<QuerySnapshot> listenForIncomingCalls(String myUid) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: myUid)
        .where('status', isEqualTo: 'ringing')
        .snapshots();
  }

  /// Listen to a specific call's status (used by the caller to see if answered)
  Stream<DocumentSnapshot> listenToCallState(String chatId) {
    return _firestore.collection('calls').doc(chatId).snapshots();
  }

  /// Initiate a call
  Future<void> dialUser({
    required String callerId,
    required String receiverId,
    required bool isVideo,
  }) async {
    final chatId = getChatId(callerId, receiverId);
    final roomName = 'datedash-${chatId.replaceAll('_', '-')}';

    final callerDoc = await _firestore.collection('users').doc(callerId).get();
    final callerData = callerDoc.data() ?? {};
    
    // Extract photo from imageUrls array if available
    String callerPhoto = '';
    if (callerData['imageUrls'] != null && (callerData['imageUrls'] as List).isNotEmpty) {
      callerPhoto = callerData['imageUrls'][0] as String;
    }

    await _firestore.collection('calls').doc(chatId).set({
      'callerId': callerId,
      'callerName': callerData['firstName'] ?? 'Unknown User',
      'callerPhoto': callerPhoto,
      'receiverId': receiverId,
      'isVideo': isVideo,
      'roomName': roomName,
      'status': 'ringing',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Accept a call
  Future<void> answerCall(String chatId) async {
    await _firestore.collection('calls').doc(chatId).update({
      'status': 'answered',
    });
  }

  /// End or reject a call
  Future<void> endCall(String chatId) async {
    try {
      await _firestore.collection('calls').doc(chatId).delete();
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }
}
