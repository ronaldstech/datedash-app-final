import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../services/video_chat_service.dart';
import '../services/profile_service.dart';
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
  final VideoChatService _videoChatService = VideoChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  static const _securityChannel = MethodChannel('com.example.datedash/security');

  int _callDuration = 0;
  Timer? _durationTimer;
  StreamSubscription<DocumentSnapshot>? _ticketSubscription;
  StreamSubscription<DocumentSnapshot>? _partnerTicketSubscription;

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isPartnerMuted = false;
  bool _isPartnerCameraOff = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _listenToCallLifecycle();
    _secureScreen();
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

  void _showReportBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report & Block', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          'Do you want to report and block this user? You will immediately exit the call and they will not be able to match with you again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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

  void _blockUser() async {
    final pp = context.read<ProfileProvider>();
    final currentUserId = pp.userProfile?.uid;
    if (currentUserId != null) {
      if (!pp.userProfile!.blockedUsers.contains(widget.partnerId)) {
        pp.userProfile!.blockedUsers.add(widget.partnerId);
        await ProfileService().saveUserProfile(currentUserId, pp.userProfile!);
      }
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': currentUserId,
        'reportedId': widget.partnerId,
        'timestamp': FieldValue.serverTimestamp(),
        'reason': 'Blocked during video call',
      });
      _endCall();
    }
  }

  @override
  void dispose() {
    _clearSecureScreen();
    _durationTimer?.cancel();
    _ticketSubscription?.cancel();
    _partnerTicketSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  void _listenToCallLifecycle() {
    final pp = context.read<ProfileProvider>();
    final currentUserId = pp.userProfile?.uid;

    if (currentUserId != null) {
      // Listen to our own ticket. If it is deleted, the partner has left the call.
      _ticketSubscription = _videoChatService.getTicketStream(currentUserId).listen((snapshot) {
        if (!snapshot.exists && mounted) {
          _exitCallScreen(showMessage: 'Call ended by partner');
        }
      });

      // Listen to partner's ticket. If it is deleted, partner has left.
      _partnerTicketSubscription = _videoChatService.getTicketStream(widget.partnerId).listen((snapshot) {
        if (!snapshot.exists && mounted) {
          _exitCallScreen(showMessage: 'Call ended by partner');
        }
      });
    }
  }

  void _sendMessage() {
    if (_callDuration < 60) return;
    if (_messageController.text.trim().isEmpty) return;
    final pp = context.read<ProfileProvider>();
    final messageText = _messageController.text.trim();
    _messageController.clear();

    FirebaseFirestore.instance
        .collection('video_chat_calls')
        .doc(widget.channelId)
        .collection('messages')
        .add({
      'senderId': pp.userProfile?.uid ?? '',
      'senderName': pp.userProfile?.firstName ?? 'User',
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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }



  void _endCall() async {
    final pp = context.read<ProfileProvider>();
    final currentUserId = pp.userProfile?.uid;
    if (currentUserId != null) {
      await _videoChatService.endCall(currentUserId, widget.partnerId);
    }
    _exitCallScreen();
  }

  void _skipAndNext() async {
    final pp = context.read<ProfileProvider>();
    final currentUserId = pp.userProfile?.uid;
    if (currentUserId != null) {
      await _videoChatService.endCall(currentUserId, widget.partnerId);
    }
    if (mounted) {
      Navigator.pop(context); // Return to matchmaking screen
    }
  }

  void _exitCallScreen({String? showMessage}) {
    _durationTimer?.cancel();
    _ticketSubscription?.cancel();
    _partnerTicketSubscription?.cancel();
    
    if (mounted) {
      if (showMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(showMessage), backgroundColor: const Color(0xFFFF4D85)),
        );
      }
      Navigator.pop(context);
    }
  }

  String _formatDuration(int seconds) {
    final min = (seconds / 60).floor().toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
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

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProfileProvider>();
    final userPhoto = pp.photoURL ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            // 1. Dual Video Stream Layer
            Column(
              children: [
                // Partner Video (Top Half)
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildVideoPlayer(
                        photo: widget.partnerPhoto,
                        name: widget.partnerName,
                        isCameraOff: _isPartnerCameraOff,
                        isMuted: _isPartnerMuted,
                      ),
                      Positioned(
                        left: 16,
                        top: 50,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.partnerName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 2,
                  color: const Color(0xFFFF4D85),
                ),
                // My Video (Bottom Half)
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildVideoPlayer(
                        photo: userPhoto,
                        name: 'You',
                        isCameraOff: _isCameraOff,
                        isMuted: _isMuted,
                      ),
                      Positioned(
                        left: 16,
                        top: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Gradient Overlay
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.2, 0.8, 1.0],
                  ),
                ),
              ),
            ),

            // Top Status Bar (Duration & Next/Skip)
            Positioned(
              top: 50,
              right: 16,
              left: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Report & Block Button
                  IconButton(
                    onPressed: _showReportBlockDialog,
                    icon: const Icon(Iconsax.shield_cross, color: Colors.redAccent, size: 24),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(8),
                    ),
                    tooltip: 'Report & Block',
                  ),
                  // Call Duration Timer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D85),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4D85).withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Skip / Next Button (Highly visible!)
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4D85), Color(0xFFFF758F)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4D85).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _skipAndNext,
                      icon: const Icon(Iconsax.next, color: Colors.white, size: 16),
                      label: const Text(
                        'Next',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Live Chat Area & Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(bottom: 32, top: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Messages Display
                    Container(
                      height: 150,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              final isMe = data['senderId'] == pp.userProfile?.uid;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$senderName: ',
                                      style: TextStyle(
                                        color: isMe ? const Color(0xFFFF4D85) : Colors.amber,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        message,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Controls Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Message Input field
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _messageController,
                                      enabled: _callDuration >= 60,
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: _callDuration < 60
                                            ? 'Chat unlocks in ${60 - _callDuration}s'
                                            : 'Type a message...',
                                        hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                                        prefixIcon: _callDuration < 60
                                            ? const Icon(Iconsax.lock5, color: Colors.white38, size: 16)
                                            : null,
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      ),
                                      onSubmitted: (_) => _sendMessage(),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _callDuration >= 60 ? _sendMessage : null,
                                    icon: Icon(
                                      Iconsax.send_1,
                                      color: _callDuration >= 60 ? const Color(0xFFFF4D85) : Colors.white24,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Mute Mic Button
                          _buildRoundButton(
                            icon: _isMuted ? Iconsax.microphone_slash5 : Iconsax.microphone5,
                            color: _isMuted ? Colors.redAccent : Colors.white24,
                            onTap: () {
                              setState(() {
                                _isMuted = !_isMuted;
                              });
                            },
                          ),
                          const SizedBox(width: 8),

                          // Toggle Camera Button
                          _buildRoundButton(
                            icon: _isCameraOff ? Iconsax.camera_slash5 : Iconsax.camera5,
                            color: _isCameraOff ? Colors.redAccent : Colors.white24,
                            onTap: () {
                              setState(() {
                                _isCameraOff = !_isCameraOff;
                              });
                            },
                          ),
                          const SizedBox(width: 8),

                          // Gift Button
                          _buildRoundButton(
                            icon: Iconsax.gift,
                            color: Colors.amber,
                            onTap: _showGifts,
                          ),
                          const SizedBox(width: 8),

                          // End Call Button
                          _buildRoundButton(
                            icon: Iconsax.call_remove5,
                            color: Colors.red,
                            onTap: _endCall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer({
    required String photo,
    required String name,
    required bool isCameraOff,
    required bool isMuted,
  }) {
    return Container(
      color: const Color(0xFF111115),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // Background photo (normal or dark overlay depending on camera state)
          if (photo.isNotEmpty)
            Image.network(
              photo,
              fit: BoxFit.cover,
              color: isCameraOff ? Colors.black.withValues(alpha: 0.8) : null,
              colorBlendMode: isCameraOff ? BlendMode.multiply : null,
            ),

          // Glassmorphic blur if camera is off
          if (isCameraOff)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ),

          // Central overlay icons/text
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isCameraOff) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.camera_slash5,
                      color: Colors.white70,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$name has turned off camera',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else ...[
                  // Connected badge at the bottom
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 80),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4D85).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.video5, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            name == 'You' ? 'Previewing' : 'Connected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Muted indicator overlay
          if (isMuted)
            Positioned(
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.microphone_slash5,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
