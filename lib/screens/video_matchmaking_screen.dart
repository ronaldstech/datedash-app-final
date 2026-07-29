import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/user_profile_model.dart';
import '../providers/profile_provider.dart';
import '../services/video_chat_service.dart';
import 'video_call_screen.dart';

class VideoMatchmakingScreen extends StatefulWidget {
  const VideoMatchmakingScreen({
    super.key,
    required this.currentUser,
    required this.filterLanguage,
    required this.filterGender,
    required this.filterMinAge,
    required this.filterMaxAge,
    required this.filterCountry,
  });

  final UserProfile currentUser;
  final String filterLanguage;
  final String filterGender;
  final int filterMinAge;
  final int filterMaxAge;
  final String filterCountry;

  @override
  State<VideoMatchmakingScreen> createState() => _VideoMatchmakingScreenState();
}

class _VideoMatchmakingScreenState extends State<VideoMatchmakingScreen>
    with SingleTickerProviderStateMixin {
  static const String _agoraAppId = '45fbe0e2e7b844bfab588523c914bfb2';

  final VideoChatService _videoChatService = VideoChatService();
  RtcEngine? _engine;
  StreamSubscription<DocumentSnapshot>? _ticketSubscription;
  late AnimationController _pulseController;

  bool _previewReady = false;
  bool _isSearching = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isAccepting = false;
  bool _navigatingToCall = false;
  Map<String, dynamic>? _proposal;

  String get _userId => widget.currentUser.uid!;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _initCameraPreview();
    _listenToTicket();
    _search();
  }

  @override
  void dispose() {
    _ticketSubscription?.cancel();
    _pulseController.dispose();
    _disposePreview();
    if (!_navigatingToCall) {
      _videoChatService.cancelMatching(_userId);
    }
    super.dispose();
  }

  Future<void> _initCameraPreview() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    if (statuses[Permission.camera] != PermissionStatus.granted ||
        statuses[Permission.microphone] != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera and microphone are required.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    final engine = createAgoraRtcEngine();
    await engine.initialize(
      const RtcEngineContext(
        appId: _agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
    await engine.enableAudio();
    await engine.enableVideo();
    await engine.startPreview();

    if (!mounted) {
      await engine.release();
      return;
    }

    setState(() {
      _engine = engine;
      _previewReady = true;
    });
  }

  Future<void> _disposePreview() async {
    final engine = _engine;
    _engine = null;
    if (engine == null) return;
    try {
      await engine.stopPreview();
      await engine.release();
    } catch (_) {}
  }

  void _listenToTicket() {
    _ticketSubscription = _videoChatService.getTicketStream(_userId).listen((
      snapshot,
    ) {
      if (!mounted || !snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return;

      final status = data['status'] as String?;
      if (status == 'proposed') {
        setState(() {
          _isSearching = false;
          _proposal = {
            'channelId': data['channelId'],
            'matchedWith': data['matchedWith'],
            'partnerName': data['partnerName'] ?? 'User',
            'partnerPhoto': data['partnerPhoto'] ?? '',
            'partnerGender': data['partnerGender'] ?? 'Other',
            'partnerAge': (data['partnerAge'] as num?)?.toInt() ?? 25,
            'partnerCountry': data['partnerCountry'] ?? 'Unknown',
            'isHost': data['isHost'] == true,
          };
        });
      } else if (status == 'matched') {
        _openCallFromTicket(data);
      } else if (status == 'waiting' && _proposal != null) {
        setState(() {
          _proposal = null;
          _isAccepting = false;
        });
        _search();
      }
    });
  }

  Future<void> _search() async {
    if (_isSearching || _proposal != null || _navigatingToCall) return;

    setState(() => _isSearching = true);
    final result = await _videoChatService.startMatching(
      currentUser: widget.currentUser,
      filterLanguage: widget.filterLanguage,
      filterGender: widget.filterGender,
      filterMinAge: widget.filterMinAge,
      filterMaxAge: widget.filterMaxAge,
      filterCountry: widget.filterCountry,
    );

    if (!mounted || _navigatingToCall) return;
    if (result != null) {
      setState(() {
        _isSearching = false;
        _proposal = result;
      });
    }
  }

  Future<void> _acceptProposal() async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    final result = await _videoChatService.acceptMatch(_userId);
    if (!mounted) return;
    if (result != null) {
      _openCall(result);
    }
  }

  Future<void> _nextProposal() async {
    setState(() {
      _proposal = null;
      _isAccepting = false;
      _isSearching = true;
    });
    await _videoChatService.declineMatch(_userId);
    if (mounted) {
      setState(() => _isSearching = false);
      _search();
    }
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _engine?.muteLocalAudioStream(_isMuted);
  }

  Future<void> _toggleCamera() async {
    setState(() => _isCameraOff = !_isCameraOff);
    await _engine?.muteLocalVideoStream(_isCameraOff);
  }

  Future<void> _switchCamera() async {
    await _engine?.switchCamera();
  }

  void _openCallFromTicket(Map<String, dynamic> data) {
    final partnerId = data['matchedWith'] as String?;
    final channelId = data['channelId'] as String?;
    if (partnerId == null || channelId == null) return;

    _openCall({
      'channelId': channelId,
      'matchedWith': partnerId,
      'partnerName': data['partnerName'] ?? 'User',
      'partnerPhoto': data['partnerPhoto'] ?? '',
      'isHost': data['isHost'] == true,
    });
  }

  Future<void> _openCall(Map<String, dynamic> data) async {
    if (_navigatingToCall) return;
    _navigatingToCall = true;
    await _ticketSubscription?.cancel();
    await _disposePreview();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          channelId: data['channelId'],
          partnerId: data['matchedWith'],
          partnerName: data['partnerName'] ?? 'User',
          partnerPhoto: data['partnerPhoto'] ?? '',
          isHost: data['isHost'] == true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPhoto = context.watch<ProfileProvider>().photoURL ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildCameraPreview()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Column(
                children: [
                  _buildTopBar(),
                  const Spacer(),
                  if (_proposal == null) _buildSearchingPanel(currentPhoto),
                  if (_proposal != null) _buildProposalCard(_proposal!),
                  const SizedBox(height: 18),
                  _buildControls(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_isCameraOff) {
      return Container(
        color: const Color(0xFF111116),
        child: const Center(
          child: Icon(Iconsax.video_slash, color: Colors.white38, size: 72),
        ),
      );
    }

    if (!_previewReady || _engine == null) {
      return Container(
        color: const Color(0xFF111116),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF4D85)),
        ),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Iconsax.arrow_left_2, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.28),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Video Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              StreamBuilder<int>(
                stream: _videoChatService.getActiveVideoUsersCountStream(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Text(
                    '$count users chatting now',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4D85).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.45, end: 1).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: const Icon(Icons.circle, color: Colors.white, size: 8),
              ),
              const SizedBox(width: 7),
              Text(
                _proposal == null ? 'Searching' : 'Found',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchingPanel(String currentPhoto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.08).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF4D85).withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                ),
              ),
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFFFF4D85),
                backgroundImage:
                    currentPhoto.isNotEmpty ? NetworkImage(currentPhoto) : null,
                child: currentPhoto.isEmpty
                    ? const Icon(Iconsax.user, color: Colors.white, size: 30)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching ? 'Finding someone for you...' : 'Waiting for users',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _criteriaChip(Iconsax.language_square, widget.filterLanguage),
              _criteriaChip(Iconsax.user, widget.filterGender),
              _criteriaChip(
                Iconsax.calendar,
                '${widget.filterMinAge}-${widget.filterMaxAge}',
              ),
              _criteriaChip(Iconsax.global, widget.filterCountry),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProposalCard(Map<String, dynamic> proposal) {
    final photo = proposal['partnerPhoto']?.toString() ?? '';
    final name = proposal['partnerName']?.toString() ?? 'User';
    final gender = proposal['partnerGender']?.toString() ?? 'Other';
    final age = proposal['partnerAge']?.toString() ?? '';
    final country = proposal['partnerCountry']?.toString() ?? 'Unknown';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D85).withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: const Color(0xFFFF4D85),
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty
                ? const Icon(Iconsax.user, color: Colors.white, size: 36)
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            age.isEmpty ? name : '$name, $age',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$gender  |  $country',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          if (_isAccepting)
            Text(
              'Waiting for $name to accept...',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _nextProposal,
                    icon: const Icon(Iconsax.arrow_right_3),
                    label: const Text('Next'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.32),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _acceptProposal,
                    icon: const Icon(Iconsax.video_tick),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D85),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _controlButton(
          icon: _isMuted ? Iconsax.microphone_slash5 : Iconsax.microphone_2,
          onPressed: _toggleMute,
        ),
        _controlButton(icon: Iconsax.rotate_left, onPressed: _switchCamera),
        _controlButton(
          icon: _isCameraOff ? Iconsax.video_slash : Iconsax.video,
          onPressed: _toggleCamera,
        ),
        _controlButton(
          icon: Iconsax.close_circle,
          color: Colors.redAccent,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color color = Colors.white,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.42),
        fixedSize: const Size(52, 52),
      ),
    );
  }

  Widget _criteriaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFF4D85), size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
