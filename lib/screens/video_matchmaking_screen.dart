import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
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
  final VideoChatService _videoChatService = VideoChatService();
  StreamSubscription<DocumentSnapshot>? _ticketSubscription;
  Timer? _searchRetryTimer;
  late AnimationController _pulseController;

  bool _isSearching = false;
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
    _listenToTicket();
    _search();
    _startSearchRetry();
  }

  @override
  void dispose() {
    _ticketSubscription?.cancel();
    _searchRetryTimer?.cancel();
    _pulseController.dispose();
    if (!_navigatingToCall) {
      _videoChatService.cancelMatching(_userId);
    }
    super.dispose();
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
    }, onError: (error) {
      debugPrint('Video matchmaking ticket listener failed: $error');
    });
  }

  void _startSearchRetry() {
    _searchRetryTimer?.cancel();
    _searchRetryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _proposal != null || _navigatingToCall) return;
      _search();
    });
  }

  Future<void> _search() async {
    if (_isSearching || _proposal != null || _navigatingToCall) return;

    setState(() => _isSearching = true);
    Map<String, dynamic>? result;
    try {
      result = await _videoChatService.startMatching(
        currentUser: widget.currentUser,
        filterLanguage: widget.filterLanguage,
        filterGender: widget.filterGender,
        filterMinAge: widget.filterMinAge,
        filterMaxAge: widget.filterMaxAge,
        filterCountry: widget.filterCountry,
      );
    } catch (error) {
      debugPrint('Video matchmaking search failed: $error');
    }

    if (!mounted || _navigatingToCall) return;
    if (result != null) {
      setState(() {
        _isSearching = false;
        _proposal = result;
      });
    } else {
      setState(() => _isSearching = false);
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
          Positioned.fill(child: _buildWaitingBackdrop(currentPhoto)),
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
                  _buildCancelButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingBackdrop(String currentPhoto) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111116),
            Color(0xFF26131C),
            Color(0xFF111116),
          ],
        ),
      ),
      child: Center(
        child: CircleAvatar(
          radius: 84,
          backgroundColor: const Color(0xFFFF4D85).withValues(alpha: 0.18),
          backgroundImage: currentPhoto.isNotEmpty
              ? NetworkImage(currentPhoto)
              : null,
          child: currentPhoto.isEmpty
              ? const Icon(Iconsax.user, color: Colors.white54, size: 72)
              : null,
        ),
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
            backgroundColor: Colors.black.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Speed Video Match',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  letterSpacing: -0.3,
                ),
              ),
              StreamBuilder<int>(
                stream: _videoChatService.getActiveVideoUsersCountStream(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$count active users chatting',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _proposal == null
                  ? [const Color(0xFFFF4D85), const Color(0xFFFF8C00)]
                  : [const Color(0xFF00E676), const Color(0xFF00B0FF)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (_proposal == null
                        ? const Color(0xFFFF4D85)
                        : const Color(0xFF00E676))
                    .withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.4, end: 1).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Icon(
                  _proposal == null ? Iconsax.radar_1 : Iconsax.tick_circle,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _proposal == null ? 'Searching' : 'Matched!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D85).withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer radar ring
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.35).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF4D85).withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Inner radar ring
              ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.15).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF8C00).withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Avatar
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF4D85), Color(0xFFFF8C00)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.black,
                  backgroundImage: currentPhoto.isNotEmpty
                      ? NetworkImage(currentPhoto)
                      : null,
                  child: currentPhoto.isEmpty
                      ? const Icon(Iconsax.user, color: Colors.white, size: 36)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _isSearching
                ? 'Looking for video match...'
                : 'Waiting in queue...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scanning users matching your criteria',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _criteriaChip(Iconsax.language_square, widget.filterLanguage),
              _criteriaChip(Iconsax.user, widget.filterGender),
              _criteriaChip(
                Iconsax.calendar,
                '${widget.filterMinAge}-${widget.filterMaxAge} yrs',
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: const Color(0xFFFF4D85).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D85).withValues(alpha: 0.35),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Match Found Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF4D85).withValues(alpha: 0.2),
                  const Color(0xFFFF8C00).withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF4D85).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Iconsax.magic_star, color: Color(0xFFFFD700), size: 16),
                SizedBox(width: 6),
                Text(
                  'MATCH FOUND!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Partner Photo Avatar with Glowing Halo
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4D85), Color(0xFFFF8C00), Color(0xFFFFD700)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4D85).withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.black,
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty
                  ? const Icon(Iconsax.user, color: Colors.white, size: 44)
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            age.isEmpty ? name : '$name, $age',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.user,
                  color: Colors.white.withValues(alpha: 0.7), size: 14),
              const SizedBox(width: 4),
              Text(
                gender,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                '  •  ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Iconsax.global,
                  color: Colors.white.withValues(alpha: 0.7), size: 14),
              const SizedBox(width: 4),
              Text(
                country,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          if (_isAccepting)
            Column(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFFFF4D85),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Connecting video call with $name...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _nextProposal,
                    icon: const Icon(Iconsax.arrow_right_3, size: 18),
                    label: const Text(
                      'Next',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4D85), Color(0xFFFF8C00)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4D85).withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _acceptProposal,
                      icon: const Icon(Iconsax.video_tick, size: 20),
                      label: const Text(
                        'Accept',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return IconButton(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Iconsax.close_circle, color: Colors.redAccent, size: 30),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        fixedSize: const Size(58, 58),
      ),
    );
  }

  Widget _criteriaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
