import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // Agora configurations
  static const String agoraAppId = '45fbe0e2e7b844bfab588523c914bfb2';
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localUserJoined = false;

  int _callDuration = 0;
  Timer? _durationTimer;
  StreamSubscription<DocumentSnapshot>? _callSessionSubscription;
  StreamSubscription<DocumentSnapshot>? _ticketSubscription;
  StreamSubscription<DocumentSnapshot>? _partnerTicketSubscription;
  bool _callLifecycleReady = false; // grace period flag

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isPartnerMuted = false;
  bool _isPartnerCameraOff = false;

  // DEBUG — remove after fixing
  String _agoraStatus = 'initialising...';

  @override
  void initState() {
    super.initState();
    _startTimer();
    _secureScreen();
    // Give a 2-second grace period before the lifecycle listener can exit the call.
    // This prevents false 'call ended' triggers during initial Firestore propagation.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _callLifecycleReady = true;
        _listenToCallLifecycle();
      }
    });
    // Auto-connect to Agora live video & audio call when matchmaking is connected
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _initAgora();
      }
    });
  }

  Future<void> _initAgora() async {
    // 1. Request Camera and Microphone permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (statuses[Permission.camera] != PermissionStatus.granted ||
        statuses[Permission.microphone] != PermissionStatus.granted) {
      debugPrint('Camera or Microphone permission not granted');
      return;
    }

    if (_engine != null) return;

    try {
      // 2. Create the engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("[Agora] Local user ${connection.localUid} joined channel: ${connection.channelId}");
            if (mounted) {
              setState(() {
                _localUserJoined = true;
                _agoraStatus = 'joined as uid=${connection.localUid}';
              });
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("[Agora] Remote user $remoteUid joined channel: ${connection.channelId}");
            if (mounted) {
              setState(() {
                _remoteUid = remoteUid;
                _agoraStatus = 'remote=$remoteUid connected ✓';
              });
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint("[Agora] Remote user $remoteUid left channel. Reason: $reason");
            if (mounted) {
              setState(() {
                _remoteUid = null;
                _agoraStatus = 'remote left ($reason)';
              });
            }
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[Agora] ERROR: code=$err msg=$msg');
            if (mounted) setState(() => _agoraStatus = 'ERROR: $err - $msg');
          },
          onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            debugPrint('[Agora] Connection state: $state reason: $reason channel: ${connection.channelId}');
            if (mounted) setState(() => _agoraStatus = '${state.name} (${reason.name})');
          },
        ),
      );

      await _engine!.enableAudio();
      await _engine!.enableVideo();
      await _engine!.startPreview();

      // Ensure proper mute / camera off values are set on joining
      await _engine!.muteLocalAudioStream(_isMuted);
      await _engine!.muteLocalVideoStream(_isCameraOff);

      // 3. Fetch a valid token from our Cloud Function (App Certificate is enabled)
      debugPrint('[Agora] Joining channel: "${widget.channelId}" (length=${widget.channelId.length})');
      final String agoraToken = await _fetchAgoraToken(widget.channelId);

      await _engine!.joinChannel(
        token: agoraToken,
        channelId: widget.channelId,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (e) {
      debugPrint('Error initializing Agora: $e');
    }
  }

  /// Calls the Cloud Function to generate a short-lived Agora RTC token.
  Future<String> _fetchAgoraToken(String channelId) async {
    try {
      final uri = Uri.parse(
        'https://us-central1-datedash-35789.cloudfunctions.net/generateAgoraToken'
        '?channelName=${Uri.encodeComponent(channelId)}&uid=0',
      );
      final response = await HttpClient()
          .getUrl(uri)
          .then((req) => req.close());
      final body = await response.transform(const Utf8Decoder()).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final token = json['token'] as String?;
      if (token != null && token.isNotEmpty) {
        debugPrint('[Agora] Token fetched successfully');
        return token;
      }
      debugPrint('[Agora] Token fetch returned empty: $body');
    } catch (e) {
      debugPrint('[Agora] Token fetch failed: $e');
    }
    return ''; // fallback — will fail if cert is enabled but better than crashing
  }

  Future<void> _disposeAgora() async {
    if (_engine != null) {
      try {
        await _engine!.leaveChannel();
        await _engine!.release();
      } catch (e) {
        debugPrint('Error disposing Agora: $e');
      }
      _engine = null;
    }
  }

  Future<void> _updateMyDeviceState() async {
    final pp = context.read<ProfileProvider>();
    final currentUserId = pp.userProfile?.uid;

    // Apply locally/engine-wise
    if (_engine != null) {
      await _engine!.muteLocalAudioStream(_isMuted);
      await _engine!.muteLocalVideoStream(_isCameraOff);
    }

    if (currentUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('video_chat_waiting')
            .doc(currentUserId)
            .update({
          'isMuted': _isMuted,
          'isCameraOff': _isCameraOff,
        });
      } catch (e) {
        debugPrint('Error updating device state in Firestore: $e');
      }
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
      await _videoChatService.endCall(currentUserId, widget.channelId);
      _exitCallScreen();
    }
  }

  @override
  void dispose() {
    _disposeAgora();
    _clearSecureScreen();
    _durationTimer?.cancel();
    _callSessionSubscription?.cancel();
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

    // Listen to the dedicated call session document.
    // It is set to 'active' when the match is made and 'ended' when either side ends.
    _callSessionSubscription = _videoChatService
        .getCallSessionStream(widget.channelId)
        .listen((snapshot) {
      if (!mounted || !_callLifecycleReady) return;

      if (!snapshot.exists) {
        // Session doc deleted — treat as ended
        _exitCallScreen(showMessage: 'Call ended by partner');
        if (currentUserId != null) {
          _videoChatService.cleanupOwnTicket(currentUserId);
        }
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return;

      final status = data['status'] as String?;
      final endedBy = data['endedBy'] as String?;

      if (status == 'ended' && endedBy != currentUserId) {
        // Partner ended the call
        _exitCallScreen(showMessage: 'Call ended by partner');
        if (currentUserId != null) {
          _videoChatService.cleanupOwnTicket(currentUserId);
        }
      }

      // Also sync partner device state from the partner's ticket if needed
      // (mute/camera state is tracked separately via Firestore ticket fields)
    });

    // Still watch partner's ticket for mute/camera state sync
    if (currentUserId != null) {
      _partnerTicketSubscription = _videoChatService.getTicketStream(widget.partnerId).listen((snapshot) {
        if (!snapshot.exists || !mounted) return;
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null && mounted) {
          setState(() {
            _isPartnerMuted = data['isMuted'] ?? false;
            _isPartnerCameraOff = data['isCameraOff'] ?? false;
          });
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
      await _videoChatService.endCall(currentUserId, widget.channelId);
    }
    _exitCallScreen();
  }

  void _skipAndNext() async {
    final pp = context.read<ProfileProvider>();
    final currentUserId = pp.userProfile?.uid;
    if (currentUserId != null) {
      await _videoChatService.endCall(currentUserId, widget.channelId);
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
                        isLocal: false,
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
                        isLocal: true,
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
                              _updateMyDeviceState();
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
                              _updateMyDeviceState();
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

            // Floating Join Call Button to manually reconnect Agora room
            if (!_localUserJoined)
              Positioned(
                right: 16,
                top: 110,
                child: ElevatedButton.icon(
                  onPressed: _initAgora,
                  icon: const Icon(Iconsax.video5, size: 16),
                  label: const Text(
                    'Join Call',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D85),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
          // DEBUG OVERLAY — remove after fixing
          Positioned(
            bottom: 120,
            left: 8,
            right: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CH: ${widget.channelId}', style: const TextStyle(color: Colors.yellow, fontSize: 9, fontFamily: 'monospace')),
                    Text('Status: $_agoraStatus', style: const TextStyle(color: Colors.greenAccent, fontSize: 9)),
                    Text('localJoined=$_localUserJoined  remoteUid=$_remoteUid', style: const TextStyle(color: Colors.cyanAccent, fontSize: 9)),
                  ],
                ),
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
    required bool isLocal,
  }) {
    // Local preview is available as soon as the engine+preview started (no need to wait for join).
    // Remote video requires remoteUid to be set after the partner joins.
    final bool showLocalVideo = isLocal && _engine != null && !isCameraOff;
    final bool showRemoteVideo = !isLocal && _engine != null && _remoteUid != null && !isCameraOff;

    return Container(
      color: const Color(0xFF111115),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // 1. Agora video stream OR background profile photo fallback
          if (showLocalVideo)
            AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _engine!,
                canvas: const VideoCanvas(uid: 0),
              ),
            )
          else if (showRemoteVideo)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine!,
                canvas: VideoCanvas(uid: _remoteUid),
                connection: RtcConnection(channelId: widget.channelId),
              ),
            )
          else if (photo.isNotEmpty)
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
