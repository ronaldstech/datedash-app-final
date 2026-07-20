import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/call_service.dart';
import '../screens/incoming_call_screen.dart';

class CallListenerWrapper extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const CallListenerWrapper({super.key, required this.child, required this.navigatorKey});

  @override
  State<CallListenerWrapper> createState() => _CallListenerWrapperState();
}

class _CallListenerWrapperState extends State<CallListenerWrapper> {
  final CallService _callService = CallService();
  String? _currentIncomingCallId;
  bool _isPushPending = false;
  
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _callSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_handleAuthChange);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _callSubscription?.cancel();
    super.dispose();
  }

  void _handleAuthChange(User? user) {
    _callSubscription?.cancel();
    _callSubscription = null;

    if (user != null) {
      _callSubscription = _callService.listenForIncomingCalls(user.uid).listen(_handleIncomingCalls);
    }
  }

  void _handleIncomingCalls(QuerySnapshot snapshot) {
    if (snapshot.docs.isNotEmpty) {
      final callDoc = snapshot.docs.first;
      final callData = callDoc.data() as Map<String, dynamic>;
      final chatId = callDoc.id;

      // Only push if this is a genuinely new incoming call
      if (_currentIncomingCallId != chatId) {
        _currentIncomingCallId = chatId;
        _safePush(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => IncomingCallScreen(
              callerName: callData['callerName'] ?? 'Unknown Caller',
              callerPhoto: callData['callerPhoto'] ?? '',
              chatId: chatId,
              isVideo: callData['isVideo'] ?? false,
              roomName: callData['roomName'] ?? 'datedash-room',
            ),
          ),
        );
      }
    } else {
      // Call was cancelled or answered
      if (_currentIncomingCallId != null && !_isPushPending) {
        _currentIncomingCallId = null;
      }
    }
  }

  /// Safely push a route only when the Navigator is ready.
  void _safePush(Route<dynamic> route) {
    if (_isPushPending) return;
    _isPushPending = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait a bit to ensure the Navigator has its initial route.
      Future.delayed(const Duration(milliseconds: 500), () {
        final navState = widget.navigatorKey.currentState;
        if (navState == null || !navState.mounted) {
          _isPushPending = false;
          _currentIncomingCallId = null; // Reset so it can try again
          return;
        }

        try {
          navState.push(route).then((_) {
            _currentIncomingCallId = null;
            _isPushPending = false;
          });
        } catch (e) {
          debugPrint('CallListenerWrapper: Navigator push failed — $e');
          _currentIncomingCallId = null;
          _isPushPending = false;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // We always return the child (Navigator) directly.
    // Reactive logic is handled via stream subscriptions above.
    return widget.child;
  }
}
