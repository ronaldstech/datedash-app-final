import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/live_stream_model.dart';
import '../services/live_stream_service.dart';
import '../providers/profile_provider.dart';
import '../models/gift_model.dart';
import '../models/user_profile_model.dart';
import '../services/profile_service.dart';

class LiveStreamScreen extends StatefulWidget {
  final String streamId;
  final bool isBroadcaster;
  final String? initialTitle;
  final LiveStream? stream;

  const LiveStreamScreen({
    super.key,
    required this.streamId,
    required this.isBroadcaster,
    this.initialTitle,
    this.stream,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen>
    with WidgetsBindingObserver {
  final LiveStreamService _liveService = LiveStreamService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  bool _isMuted = false;
  bool _isCameraOff = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _initStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _cleanupStream();
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _initStream() async {
    if (widget.isBroadcaster) {
      final pp = context.read<ProfileProvider>();
      await _liveService.startStream(
        streamId: widget.streamId,
        userId: pp.currentUser!.uid,
        userName: pp.displayName,
        userPhoto: pp.photoURL ?? '',
        title: widget.initialTitle ?? 'Live Stream',
      );
    } else {
      await _liveService.joinStream(widget.streamId);
    }
  }

  Future<void> _cleanupStream() async {
    if (widget.isBroadcaster) {
      await _liveService.endStream(widget.streamId);
    } else {
      await _liveService.leaveStream(widget.streamId);
    }
  }

  void _toggleMute() => setState(() => _isMuted = !_isMuted);
  void _toggleCamera() => setState(() => _isCameraOff = !_isCameraOff);

  // ─────────────── Chat ────────────────────────────────────────────────────────

  void _sendMessage({String? giftType, int? giftValue}) {
    if (_messageController.text.isEmpty && giftType == null) return;
    final pp = context.read<ProfileProvider>();
    _liveService.sendMessage(
      streamId: widget.streamId,
      senderId: pp.currentUser!.uid,
      senderName: pp.displayName,
      senderPhoto: pp.photoURL ?? '',
      message: giftType != null ? 'sent a $giftType!' : _messageController.text,
      giftType: giftType,
      giftValue: giftValue,
    );
    _messageController.clear();
  }

  // ─────────────── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProfileProvider>();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('live_streams')
          .doc(widget.streamId)
          .snapshots(),
      builder: (context, snapshot) {
        LiveStream? currentStream;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          currentStream = LiveStream.fromMap(data, snapshot.data!.id);
        }
        final activeStream = currentStream ?? widget.stream;
        final bool isCurrentGuest = activeStream != null &&
            activeStream.guestId == pp.currentUser!.uid &&
            activeStream.guestStatus == 'joined';

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── Video layer ───────────────────────────────────────────
              _buildVideoLayer(activeStream),

              // ── Dark gradient overlay ─────────────────────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 	0.35),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 	0.80),
                        ],
                        stops: const [0, 0.2, 0.6, 1],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Main UI ───────────────────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context, activeStream),
                    const Spacer(),
                    _buildChatAndControls(context, pp),
                  ],
                ),
              ),

              // ── Broadcaster/Guest side-bar controls ─────────────────────────
              if (widget.isBroadcaster || isCurrentGuest)
                _buildSideControls(isGuest: isCurrentGuest, stream: activeStream, pp: pp),
            ],
          ),
        );
      },
    );
  }

  // ─────────────── Video layer ─────────────────────────────────────────────────

  Widget _buildVideoLayer(LiveStream? stream) {
    final bool isGuestJoined = stream != null &&
        stream.guestStatus == 'joined' &&
        stream.guestId != null &&
        stream.guestPhoto != null;

    if (!isGuestJoined) {
      final photo = widget.isBroadcaster
          ? (context.read<ProfileProvider>().photoURL ?? '')
          : (stream?.broadcasterPhoto ?? '');
      return _buildSingleVideoPlayer(photo, widget.isBroadcaster ? 'You' : (stream?.broadcasterName ?? 'Host'), _isCameraOff);
    }

    final hostPhoto = stream.broadcasterPhoto;
    final hostName = stream.broadcasterName;
    
    final guestPhoto = stream.guestPhoto ?? '';
    final guestName = stream.guestName ?? 'Guest';

    final bool hostCamOff = widget.isBroadcaster ? _isCameraOff : false;
    final bool guestCamOff = (widget.isBroadcaster == false && stream.guestId == context.read<ProfileProvider>().currentUser?.uid) ? _isCameraOff : false;

    return Column(
      children: [
        Expanded(
          child: _buildSingleVideoPlayer(hostPhoto, '$hostName (Host)', hostCamOff),
        ),
        Container(
          height: 2,
          color: const Color(0xFFFF4D85).withValues(alpha: 	0.5),
        ),
        Expanded(
          child: _buildSingleVideoPlayer(guestPhoto, '$guestName (Co-host)', guestCamOff),
        ),
      ],
    );
  }

  Widget _buildSingleVideoPlayer(String photo, String name, bool camOff) {
    if (camOff) {
      return Container(
        color: const Color(0xFF111111),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (photo.isNotEmpty)
                CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(photo),
                ),
              const SizedBox(height: 12),
              Text(
                '$name\'s camera is off',
                style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: photo.isNotEmpty
          ? BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(photo),
                fit: BoxFit.cover,
              ),
            )
          : const BoxDecoration(color: Color(0xFF111111)),
      child: Stack(
        children: [
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 	0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── Top bar ─────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, LiveStream? stream) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFFF4D85),
            backgroundImage: NetworkImage(
              widget.isBroadcaster
                  ? (context.read<ProfileProvider>().photoURL ?? '')
                  : (stream?.broadcasterPhoto ?? ''),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isBroadcaster
                    ? 'You'
                    : (stream?.broadcasterName ?? 'Live'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
              Row(
                children: [
                  const Icon(Icons.circle, color: Colors.red, size: 8),
                  const SizedBox(width: 4),
                  const Text('LIVE',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  const SizedBox(width: 10),
                  const Icon(Iconsax.eye, color: Colors.white70, size: 12),
                  const SizedBox(width: 4),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('live_streams')
                        .doc(widget.streamId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count =
                          snapshot.hasData && snapshot.data!.exists
                              ? (snapshot.data!['viewerCount'] ?? 0)
                              : 0;
                      return Text('$count',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10));
                    },
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final navigator = Navigator.of(context);
              if (!widget.isBroadcaster) {
                final pp = context.read<ProfileProvider>();
                if (stream != null && stream.guestId == pp.currentUser!.uid) {
                  await _liveService.removeGuest(widget.streamId);
                }
              }
              navigator.pop();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 	0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.isBroadcaster ? 'END' : 'LEAVE',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── Side controls ────────────────────────────────────

  Widget _buildSideControls({
    required bool isGuest,
    required LiveStream? stream,
    required ProfileProvider pp,
  }) {
    return Positioned(
      right: 12,
      top: 0,
      bottom: 0,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _controlBtn(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: _isMuted ? 'Unmute' : 'Mute',
              onTap: _toggleMute,
              active: _isMuted,
              activeColor: Colors.red,
            ),
            const SizedBox(height: 16),
            _controlBtn(
              icon:
                  _isCameraOff ? Icons.videocam_off : Icons.videocam,
              label: _isCameraOff ? 'Show' : 'Hide',
              onTap: _toggleCamera,
              active: _isCameraOff,
              activeColor: Colors.orange,
            ),
            if (isGuest) ...[
              const SizedBox(height: 16),
              _controlBtn(
                icon: Icons.exit_to_app,
                label: 'Leave Seat',
                onTap: () async {
                  await _liveService.removeGuest(widget.streamId);
                },
                active: true,
                activeColor: Colors.redAccent,
              ),
            ],
            if (widget.isBroadcaster) ...[
              const SizedBox(height: 16),
              if (stream?.guestStatus == 'joined')
                _controlBtn(
                  icon: Icons.person_remove,
                  label: 'Remove Guest',
                  onTap: () async {
                    await _liveService.removeGuest(widget.streamId);
                  },
                  active: true,
                  activeColor: Colors.redAccent,
                )
              else
                _controlBtn(
                  icon: Icons.person_add,
                  label: 'Invite Match',
                  onTap: () => _showInviteMatchSheet(context, pp.currentUser!.uid),
                  active: false,
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showInviteMatchSheet(BuildContext context, String hostId) {
    final profileService = ProfileService();
    final pp = context.read<ProfileProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Invite a Match',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<UserProfile>>(
                stream: profileService.getMatchesStream(hostId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D85)));
                  }
                  final matches = snapshot.data ?? [];
                  if (matches.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No matches found. Swipe to get matches first!',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final match = matches[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: match.photos.isNotEmpty
                                  ? NetworkImage(match.photos.first)
                                  : null,
                              child: match.photos.isEmpty
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    match.firstName ?? 'Unknown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Text(
                                    'Matched',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                final guestPhoto = match.photos.isNotEmpty ? match.photos.first : '';
                                await _liveService.inviteGuest(
                                  streamId: widget.streamId,
                                  hostId: hostId,
                                  hostName: pp.displayName,
                                  guestId: match.uid ?? '',
                                  guestName: match.firstName ?? 'Guest',
                                  guestPhoto: guestPhoto,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Invitation sent to ${match.firstName}!'),
                                      backgroundColor: const Color(0xFFFF4D85),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF4D85),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('Invite'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    Color activeColor = Colors.red,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 	0.75)
              : Colors.black.withValues(alpha: 	0.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─────────────── Chat & input ────────────────────────────────────────────────

  Widget _buildChatAndControls(BuildContext context, ProfileProvider pp) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: StreamBuilder<List<LiveChatMessage>>(
              stream: _liveService.getMessagesStream(widget.streamId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                return ListView.builder(
                  controller: _chatScrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _buildChatMessage(messages[index]),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 	0.18),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 	0.25)),
                  ),
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Say something…',
                      hintStyle:
                          TextStyle(color: Colors.white54, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!widget.isBroadcaster)
                _actionBtn(
                  icon: Iconsax.gift,
                  color: const Color(0xFFFF4D85),
                  onTap: () => _showGiftPicker(context),
                ),
              const SizedBox(width: 8),
              _actionBtn(
                icon: Iconsax.send_1,
                color: Colors.blueAccent,
                onTap: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildChatMessage(LiveChatMessage msg) {
    final isGift = msg.giftType != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor:
                const Color(0xFFFF4D85).withValues(alpha: 	0.3),
            backgroundImage: msg.senderPhoto.isNotEmpty
                ? NetworkImage(msg.senderPhoto)
                : null,
            child: msg.senderPhoto.isEmpty
                ? const Icon(Icons.person, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: '${msg.senderName}  ',
                  style: const TextStyle(
                      color: Color(0xFFFF4D85),
                      fontWeight: FontWeight.w800,
                      fontSize: 12),
                ),
                TextSpan(
                  text: msg.message,
                  style: TextStyle(
                    color: isGift ? Colors.orangeAccent : Colors.white,
                    fontWeight:
                        isGift ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── Gift picker ──────────────────────────────────────────────────

  void _showGiftPicker(BuildContext context) {
    final gifts = GiftData.gifts;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Send a Gift',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            SizedBox(
              height: 280,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: gifts.length,
                itemBuilder: (context, index) {
                  final gift = gifts[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _sendMessage(
                        giftType: gift.name,
                        giftValue: gift.cost,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: gift.color.withValues(alpha: 	0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: gift.color.withValues(alpha: 	0.1)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(gift.icon,
                              style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 4),
                          Text(gift.name,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${gift.cost} 🪙',
                              style: TextStyle(
                                  color: gift.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
