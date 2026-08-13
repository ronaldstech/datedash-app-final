import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../services/chat_service.dart';
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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isSwitchingCamera = false;
  bool _isVideoMuted = false;
  bool _isLocalLarge = false;
  double? _pipLeft;
  double? _pipTop;

  Timer? _durationTimer;
  StreamSubscription<DocumentSnapshot>? _callSessionSubscription;
  int _callDuration = 0;
  bool _callLifecycleReady = false;

  @override
  void initState() {
    super.initState();
    _secureScreen();
    _startTimer();
    _initLocalCamera();

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
    _cameraController?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initLocalCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing local camera preview for video call: $e');
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

  Future<void> _switchCamera() async {
    if (_isSwitchingCamera) return;
    _isSwitchingCamera = true;
    try {
      final cameras = await availableCameras();
      if (cameras.length < 2) return;

      final currentLens = _cameraController?.description.lensDirection;
      final newCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == (currentLens == CameraLensDirection.front
            ? CameraLensDirection.back
            : CameraLensDirection.front),
        orElse: () => cameras.first,
      );

      // Prevent building a preview on the disposed controller during the swap
      if (mounted) setState(() => _isCameraInitialized = false);
      await _cameraController?.dispose();
      _cameraController = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Error switching camera: $e');
    } finally {
      _isSwitchingCamera = false;
    }
  }

  void _togglePreviewSwap() {
    setState(() {
      _isLocalLarge = !_isLocalLarge;
    });
  }

  void _onPipDrag(DragUpdateDetails details, BoxConstraints constraints) {
    const pipW = 110.0;
    const pipH = 155.0;
    final left =
        (_pipLeft ?? (constraints.maxWidth - pipW - 16)) + details.delta.dx;
    final top = (_pipTop ?? 80.0) + details.delta.dy;
    setState(() {
      _pipLeft = left.clamp(8.0, constraints.maxWidth - pipW - 8);
      _pipTop = top.clamp(72.0, constraints.maxHeight - pipH - 8);
    });
  }

  void _showChatBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bool isUnlocked = _callDuration >= 60;

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Color(0xFF14141A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 14,
                left: 16,
                right: 16,
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFFF4D85).withValues(alpha: 0.2),
                        backgroundImage: widget.partnerPhoto.isNotEmpty
                            ? NetworkImage(widget.partnerPhoto)
                            : null,
                        child: widget.partnerPhoto.isEmpty
                            ? const Icon(Iconsax.user, color: Colors.white, size: 20)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1-on-1 Chat with ${widget.partnerName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              isUnlocked
                                  ? '🔓 Messages save directly to Inbox'
                                  : '🔒 Unlocks in ${60 - _callDuration}s...',
                              style: TextStyle(
                                color: isUnlocked
                                    ? const Color(0xFF00E676)
                                    : const Color(0xFFFF8C00),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalContext),
                        icon: const Icon(Iconsax.close_circle, color: Colors.white54),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),

                  // Live Messages Stream
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('video_chat_calls')
                          .doc(widget.channelId)
                          .collection('messages')
                          .orderBy('timestamp', descending: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(color: Color(0xFFFF4D85)),
                          );
                        }
                        final docs = snapshot.data!.docs;
                        _scrollToBottom();

                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Iconsax.message_text,
                                  color: Colors.white.withValues(alpha: 0.2),
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isUnlocked
                                      ? 'Say hi to ${widget.partnerName}!'
                                      : 'Chat unlocks after 60 seconds of call',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

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
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFFFF4D85)
                                      : Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  isMe ? message : '$senderName: $message',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Input Box with Gifting Button
                  Row(
                    children: [
                      if (isUnlocked)
                        IconButton(
                          onPressed: _showGifts,
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                            ),
                            child: const Icon(
                              Iconsax.gift,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),
                          tooltip: 'Send Gift',
                        ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: isUnlocked,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: isUnlocked
                                ? 'Type a message (saves to Inbox)...'
                                : 'Chat unlocks in ${60 - _callDuration}s...',
                            hintStyle: TextStyle(
                              color: isUnlocked
                                  ? Colors.white54
                                  : Colors.white.withValues(alpha: 0.35),
                            ),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.4),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: isUnlocked
                                    ? const Color(0xFFFF4D85)
                                    : Colors.white12,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: isUnlocked
                                    ? const Color(0xFFFF4D85).withValues(alpha: 0.6)
                                    : Colors.white12,
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
                              onPressed: isUnlocked
                                  ? () {
                                      _sendMessage();
                                      setModalState(() {});
                                    }
                                  : null,
                              icon: Icon(
                                Iconsax.send_15,
                                color: isUnlocked
                                    ? const Color(0xFFFF4D85)
                                    : Colors.white24,
                              ),
                            ),
                          ),
                          onSubmitted: (_) {
                            if (isUnlocked) {
                              _sendMessage();
                              setModalState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // WhatsApp-style Main Video Tile (large)
                Positioned.fill(
                  child: _isLocalLarge
                      ? _buildLocalVideo(large: true)
                      : _buildRemoteVideo(),
                ),

                // Gradient Overlay for readability
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top Header Bar
                Positioned(
                  top: 14,
                  left: 16,
                  right: 16,
                  child: _buildTopBar(),
                ),

                // Draggable Small Preview Tile (Picture-in-Picture)
                Positioned(
                  left: _pipLeft ?? (constraints.maxWidth - 110 - 16),
                  top: _pipTop ?? 80,
                  child: GestureDetector(
                    onTap: _togglePreviewSwap,
                    onPanUpdate: (details) => _onPipDrag(details, constraints),
                    child: _buildPipPreview(),
                  ),
                ),

                // Skip Button above the Control Bar
                Positioned(
                  bottom: 112,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildSkipButton()),
                ),

                // Control Bar at the Bottom
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: _buildControls(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPipPreview() {
    return Container(
      width: 110,
      height: 155,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF4D85).withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _isLocalLarge ? _buildRemoteVideo() : _buildLocalVideo(),
      ),
    );
  }

  Widget _buildLocalVideo({bool large = false}) {
    final showPlaceholder = _isVideoMuted ||
        !_isCameraInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized;
    if (showPlaceholder) {
      return Container(
        color: const Color(0xFF15151A),
        child: Center(
          child: Icon(
            _isVideoMuted ? Iconsax.video_slash : Iconsax.user,
            color: Colors.white54,
            size: large ? 56 : 36,
          ),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _cameraController!.value.previewSize?.height ?? 100,
        height: _cameraController!.value.previewSize?.width ?? 100,
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    return Container(
      color: const Color(0xFF15151A),
      child: widget.partnerPhoto.isNotEmpty
          ? Image.network(widget.partnerPhoto, fit: BoxFit.cover)
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.user, color: Colors.white38, size: 56),
                  const SizedBox(height: 8),
                  Text(
                    widget.partnerName,
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
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF4D85).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.timer_1, color: Color(0xFFFF4D85), size: 16),
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
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildSkipButton() {
    return ElevatedButton.icon(
      onPressed: _skipAndNext,
      icon: const Icon(Iconsax.next, size: 16),
      label: const Text('Skip'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF4D85),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final double progress = (_callDuration / 60.0).clamp(0.0, 1.0);
    final bool isUnlocked = _callDuration >= 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Button 1: Camera Mute Toggle
          _roundButton(
            _isVideoMuted ? Iconsax.video_slash : Iconsax.video,
            _isVideoMuted ? Colors.redAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.15),
            _isVideoMuted ? Colors.redAccent : Colors.white,
            () => setState(() => _isVideoMuted = !_isVideoMuted),
          ),

          // Button 2: Switch Camera (Front/Back)
          _roundButton(
            Icons.flip_camera_android,
            Colors.white.withValues(alpha: 0.15),
            Colors.white,
            _switchCamera,
          ),

          // Button 3: Redesigned 1-on-1 Chat Button with Circular Progress Border Ring
          GestureDetector(
            onTap: _showChatBottomSheet,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Circular Progress Indicator Ring around the button
                SizedBox(
                  width: 58,
                  height: 58,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isUnlocked ? const Color(0xFF00E676) : const Color(0xFFFF4D85),
                    ),
                  ),
                ),
                // Main Circular Button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked
                        ? const Color(0xFF00E676).withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.15),
                    border: Border.all(
                      color: isUnlocked
                          ? const Color(0xFF00E676).withValues(alpha: 0.6)
                          : const Color(0xFFFF4D85).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    isUnlocked ? Iconsax.message_text : Iconsax.lock_1,
                    color: isUnlocked ? const Color(0xFF00E676) : const Color(0xFFFF4D85),
                    size: 22,
                  ),
                ),
                // Timer tag badge when locked
                if (!isUnlocked)
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF4D85).withValues(alpha: 0.6), width: 1),
                      ),
                      child: Text(
                        '${60 - _callDuration}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Button 4: Send Gift
          _roundButton(
            Iconsax.gift,
            Colors.amber.withValues(alpha: 0.2),
            Colors.amber,
            _showGifts,
          ),

          // Button 5: End Call
          _roundButton(
            Iconsax.call_remove5,
            Colors.redAccent.withValues(alpha: 0.85),
            Colors.white,
            _endCall,
          ),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}
