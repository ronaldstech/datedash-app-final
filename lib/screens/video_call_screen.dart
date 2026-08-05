import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../services/chat_service.dart';
import '../services/jitsi_call_service.dart';
import '../services/profile_service.dart';
import '../services/video_chat_service.dart';
import '../widgets/gift_selection_sheet.dart';

class VideoCallScreen extends StatefulWidget {
  final String channelId;
  final String partnerId;
  final String partnerName;
  final String partnerPhoto;
  final bool isHost;

  const VideoCallScreen({
    super.key,
    required this.channelId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerPhoto,
    required this.isHost,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  static const _securityChannel = MethodChannel('com.example.datedash/security');

  final VideoChatService _videoChatService = VideoChatService();
  final JitsiCallService _jitsiCallService = JitsiCallService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _durationTimer;
  StreamSubscription<DocumentSnapshot>? _callSessionSubscription;
  int _callDuration = 0;
  bool _launchedRoom = false;
  bool _callLifecycleReady = false;

  @override
  void initState() {
    super.initState();
    _secureScreen();
    _startTimer();
    Future.delayed(const Duration(milliseconds: 500), _launchRoom);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _callLifecycleReady = true;
      _listenToCallLifecycle();
    });
  }

  @override
  void dispose() {
    _clearSecureScreen();
    _durationTimer?.cancel();
    _callSessionSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _launchRoom() async {
    if (_launchedRoom) return;
    _launchedRoom = true;
    final launched = await _jitsiCallService.launchRoom(
      roomName: widget.channelId,
      isVideo: true,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the video room.')),
      );
    }
  }

  Future<void> _secureScreen() async {
    try {
      if (Platform.isAndroid) {
        await _securityChannel.invokeMethod('enableSecure');
      }
    } catch (_) {}
  }

  Future<void> _clearSecureScreen() async {
    try {
      if (Platform.isAndroid) {
        await _securityChannel.invokeMethod('disableSecure');
      }
    } catch (_) {}
  }

  void _startTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callDuration++);
      }
    });
  }

  void _listenToCallLifecycle() {
    final currentUserId = context.read<ProfileProvider>().userProfile?.uid;
    _callSessionSubscription = _videoChatService
        .getCallSessionStream(widget.channelId)
        .listen((snapshot) {
      if (!mounted || !_callLifecycleReady) return;

      if (!snapshot.exists) {
        _exitCallScreen(showMessage: 'Call ended by partner');
        if (currentUserId != null) {
          _videoChatService.cleanupOwnTicket(currentUserId);
        }
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>?;
      final status = data?['status'] as String?;
      final endedBy = data?['endedBy'] as String?;
      if (status == 'ended' && endedBy != currentUserId) {
        _exitCallScreen(showMessage: 'Call ended by partner');
        if (currentUserId != null) {
          _videoChatService.cleanupOwnTicket(currentUserId);
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_callDuration < 60) return;
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;
    _messageController.clear();

    final profile = context.read<ProfileProvider>().userProfile;
    final myUid = profile?.uid;
    if (myUid == null) return;

    // 1. Write to real 1-on-1 chat in Firestore so messages appear in the Chats screen!
    try {
      final chatId = await ChatService().getOrCreateChat(myUid, widget.partnerId);
      await ChatService().sendMessage(
        chatId: chatId,
        senderId: myUid,
        receiverId: widget.partnerId,
        text: messageText,
      );
    } catch (e) {
      debugPrint('Error sending real chat message: $e');
    }

    // 2. Write to in-call stream collection for live video overlay
    await FirebaseFirestore.instance
        .collection('video_chat_calls')
        .doc(widget.channelId)
        .collection('messages')
        .add({
      'senderId': myUid,
      'senderName': profile?.firstName ?? 'User',
      'message': messageText,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showReportBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Report & Block',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Do you want to report and block this user? You will immediately exit the call and they will not be able to match with you again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _blockUser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Report & Block'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser() async {
    final provider = context.read<ProfileProvider>();
    final currentUserId = provider.userProfile?.uid;
    if (currentUserId == null) return;

    if (!provider.userProfile!.blockedUsers.contains(widget.partnerId)) {
      provider.userProfile!.blockedUsers.add(widget.partnerId);
      await ProfileService().saveUserProfile(currentUserId, provider.userProfile!);
    }
    await FirebaseFirestore.instance.collection('reports').add({
      'reporterId': currentUserId,
      'reportedId': widget.partnerId,
      'timestamp': FieldValue.serverTimestamp(),
      'reason': 'Blocked during video call',
    });
    await _videoChatService.endCall(currentUserId, widget.channelId);
    _exitCallScreen();
  }

  Future<void> _endCall() async {
    final currentUserId = context.read<ProfileProvider>().userProfile?.uid;
    if (currentUserId != null) {
      await _videoChatService.endCall(currentUserId, widget.channelId);
    }
    _exitCallScreen();
  }

  Future<void> _skipAndNext() async {
    final currentUserId = context.read<ProfileProvider>().userProfile?.uid;
    if (currentUserId != null) {
      await _videoChatService.endCall(currentUserId, widget.channelId);
    }
    if (mounted) Navigator.pop(context);
  }

  void _exitCallScreen({String? showMessage}) {
    _durationTimer?.cancel();
    _callSessionSubscription?.cancel();
    if (!mounted) return;
    if (showMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(showMessage),
          backgroundColor: const Color(0xFFFF4D85),
        ),
      );
    }
    Navigator.pop(context);
  }

  void _showGifts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftSelectionSheet(
        targetUserId: widget.partnerId,
        targetUserName: widget.partnerName,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().userProfile;
    final userPhoto = profile?.photos.isNotEmpty == true ? profile!.photos.first : '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildBackdrop(userPhoto)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                children: [
                  _buildTopBar(),
                  const Spacer(),
                  _buildRoomCard(),
                  const SizedBox(height: 12),
                  if (_callDuration < 60)
                    _buildUnlockProgressWidget()
                  else
                    _buildUnlockedBanner(),
                  const SizedBox(height: 12),
                  _buildMessages(),
                  const SizedBox(height: 12),
                  _buildMessageInput(),
                  const SizedBox(height: 14),
                  _buildControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackdrop(String userPhoto) {
    return Row(
      children: [
        Expanded(child: _profileImage(widget.partnerPhoto, widget.partnerName)),
        Expanded(child: _profileImage(userPhoto, 'You')),
      ],
    );
  }

  Widget _profileImage(String photo, String name) {
    return Container(
      color: const Color(0xFF15151A),
      child: photo.isNotEmpty
          ? Image.network(photo, fit: BoxFit.cover)
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.user, color: Colors.white38, size: 56),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: _showReportBlockDialog,
          icon: const Icon(Iconsax.shield_cross, color: Colors.redAccent),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.45),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF4D85), Color(0xFFFF8C00)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D85).withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.timer_1, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                _formatDuration(_callDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _skipAndNext,
          icon: const Icon(Iconsax.next, size: 16),
          label: const Text('Next'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4D85),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Iconsax.video_tick, color: Color(0xFFFF4D85), size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Live Call with ${widget.partnerName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _launchRoom,
            icon: const Icon(Iconsax.export_3, size: 18),
            label: const Text('Open Video Call Room', style: TextStyle(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D85),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockProgressWidget() {
    final double progress = (_callDuration / 60.0).clamp(0.0, 1.0);
    final int secondsLeft = 60 - _callDuration;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF4D85).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D85).withValues(alpha: 0.2),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D85).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.lock_1,
                  color: Color(0xFFFF4D85),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '1-on-1 Chat Unlocks in Video Call',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${secondsLeft}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Glowing Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  width: double.infinity,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4D85), Color(0xFFFF8C00)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4D85).withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Video chat for 60s to unlock permanent messaging',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFFFF8C00),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00E676).withValues(alpha: 0.25),
            const Color(0xFF00B0FF).withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00E676).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: const [
          Icon(Iconsax.unlock5, color: Color(0xFF00E676), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '🔓 Real Messages Unlocked! Saved directly to your Chats inbox.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return SizedBox(
      height: 120,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('video_chat_calls')
            .doc(widget.channelId)
            .collection('messages')
            .orderBy('timestamp', descending: false)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          final docs = snapshot.data!.docs;
          _scrollToBottom();
          return ListView.builder(
            controller: _scrollController,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final senderName = data['senderName'] ?? 'User';
              final message = data['message'] ?? '';
              final myUid = context.read<ProfileProvider>().userProfile?.uid;
              final isMe = data['senderId'] == myUid;

              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFFFF4D85).withValues(alpha: 0.85)
                        : Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isMe
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    isMe ? message : '$senderName: $message',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMessageInput() {
    final bool isUnlocked = _callDuration >= 60;

    return TextField(
      controller: _messageController,
      enabled: isUnlocked,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: isUnlocked
            ? 'Type a message (saves to Chats)...'
            : 'Chat unlocks in ${60 - _callDuration}s...',
        hintStyle: TextStyle(
          color: isUnlocked
              ? Colors.white70
              : Colors.white.withValues(alpha: 0.45),
        ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.65),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: isUnlocked
                ? const Color(0xFFFF4D85).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: isUnlocked
                ? const Color(0xFFFF4D85).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: Color(0xFFFF4D85),
            width: 1.5,
          ),
        ),
        suffixIcon: IconButton(
          onPressed: isUnlocked ? _sendMessage : null,
          icon: Icon(
            Iconsax.send_15,
            color: isUnlocked
                ? const Color(0xFFFF4D85)
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ),
      onSubmitted: (_) => _sendMessage(),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _roundButton(Iconsax.video, const Color(0xFFFF4D85), _launchRoom),
        _roundButton(Iconsax.gift, Colors.amber, _showGifts),
        _roundButton(Iconsax.call_remove5, Colors.redAccent, _endCall),
      ],
    );
  }

  Widget _roundButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
