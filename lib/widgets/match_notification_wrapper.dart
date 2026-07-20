import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/live_stream_service.dart';
import '../screens/live_stream_screen.dart';
import '../services/push_notification_service.dart';

class AppNotificationWrapper extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const AppNotificationWrapper({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<AppNotificationWrapper> createState() => _AppNotificationWrapperState();
}

class _AppNotificationWrapperState extends State<AppNotificationWrapper> {
  // Notification preferences
  bool _masterEnabled = true;
  bool _soundEnabled = true;
  bool _vibrateEnabled = true;
  bool _matchesEnabled = true;
  bool _messagesEnabled = true;
  bool _likesEnabled = true;
  bool _callsEnabled = true;
  bool _liveInvitesEnabled = true;

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  StreamSubscription<QuerySnapshot>? _chatSubscription;
  StreamSubscription<User?>? _authSubscription;
  final DateTime _startTime = DateTime.now();

  // Track unread counts to detect new messages
  final Map<String, int> _lastUnreadCounts = {};

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _masterEnabled = prefs.getBool('notif_master') ?? true;
      _soundEnabled = prefs.getBool('notif_sound') ?? true;
      _vibrateEnabled = prefs.getBool('notif_vibrate') ?? true;
      _matchesEnabled = prefs.getBool('notif_matches') ?? true;
      _messagesEnabled = prefs.getBool('notif_messages') ?? true;
      _likesEnabled = prefs.getBool('notif_likes') ?? true;
      _callsEnabled = prefs.getBool('notif_calls') ?? true;
      _liveInvitesEnabled = prefs.getBool('notif_live_invites') ?? true;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_handleAuthChange);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _notificationSubscription?.cancel();
    _chatSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _handleAuthChange(User? user) {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _chatSubscription?.cancel();
    _chatSubscription = null;
    _lastUnreadCounts.clear();

    if (user != null) {
      PushNotificationService().updateTokenInFirestore(user.uid);
      // 1. Listen for general notifications (likes, views, matches)
      _notificationSubscription = FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen(_handleNotifications);

      // 2. Listen for new messages in chats
      _chatSubscription = FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: user.uid)
          .snapshots()
          .listen((snapshot) => _handleChatChanges(snapshot, user.uid));
    }
  }

  void _handleNotifications(QuerySnapshot snapshot) async {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final data = change.doc.data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        final type = data['type'] as String?;
        
        // Only play if it's a fresh notification (after app start)
        if (timestamp != null && timestamp.isAfter(_startTime)) {
          if (!_masterEnabled) return;
          if (type == 'match' && !_matchesEnabled) return;
          if (type == 'live_invite' && !_liveInvitesEnabled) return;
          if (type == 'message' && !_messagesEnabled) return;
          if (type == 'like' && !_likesEnabled) return;
          if (type == 'call' && !_callsEnabled) return;
          if (type == 'match') {
            _playSound('audios/match.mp3');
          } else {
            _playSound('audios/notification.mp3');
            if (_vibrateEnabled) {
              HapticFeedback.vibrate();
            }
          }

          if (type == 'live_invite') {
            final streamId = data['message'] as String?;
            final senderName = data['senderName'] as String? ?? 'Someone';
            final notificationId = change.doc.id;
            if (streamId != null) {
              _showLiveInviteDialog(notificationId, streamId, senderName);
            }
          }
        }
      }
    }
  }

  void _showLiveInviteDialog(String notificationId, String streamId, String senderName) {
    final context = widget.navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.video_call, color: Color(0xFFFF4D85)),
            SizedBox(width: 8),
            Text('Live Invitation', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('$senderName invited you to join their live stream as a co-host!'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({'isRead': true});
              await LiveStreamService().declineInvite(streamId);
            },
            child: const Text('Decline', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({'isRead': true});
              await LiveStreamService().acceptInvite(streamId);
              
              if (widget.navigatorKey.currentState != null) {
                widget.navigatorKey.currentState!.push(
                  MaterialPageRoute(
                    builder: (_) => LiveStreamScreen(
                      streamId: streamId,
                      isBroadcaster: false,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D85),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Join Live'),
          ),
        ],
      ),
    );
  }

  void _handleChatChanges(QuerySnapshot snapshot, String myUid) {
    for (var change in snapshot.docChanges) {
      final data = change.doc.data() as Map<String, dynamic>;
      final chatId = change.doc.id;
      final unreadCount = (data['unreadCount'] as Map<String, dynamic>?) ?? {};
      final myUnread = (unreadCount[myUid] as num?)?.toInt() ?? 0;
      final lastSenderId = data['lastMessageSenderId'] as String?;
      final lastTime = (data['lastMessageTime'] as Timestamp?)?.toDate();

      // Only care about messages from OTHERS that arrived AFTER app start
      if (lastSenderId != null && 
          lastSenderId != myUid && 
          lastTime != null && 
          lastTime.isAfter(_startTime)) {
        
        final previousUnread = _lastUnreadCounts[chatId] ?? 0;
        
        // If unread count increased, play sound
        if (myUnread > previousUnread) {
          _playSound('audios/notification.mp3');
          if (_vibrateEnabled) {
            HapticFeedback.vibrate();
          }
        }
      }
      
      // Update local tracking
      _lastUnreadCounts[chatId] = myUnread;
    }
  }

  Future<void> _playSound(String assetPath) async {
    if (!_soundEnabled) return;

    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('AppNotificationWrapper: Error playing sound $assetPath — $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
