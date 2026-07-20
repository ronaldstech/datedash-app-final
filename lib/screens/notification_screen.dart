import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../models/user_profile_model.dart';
import '../providers/profile_provider.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../widgets/profile_detail_sheet.dart';
import '../utils/date_formatter.dart';
import '../providers/language_provider.dart';
import 'chat_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final ProfileService _profileService = ProfileService();
  Stream<List<DatedashNotification>>? _notificationsStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _notificationsStream =
          _notificationService.getNotificationsStream(user.uid);
    }
  }

  Map<String, List<DatedashNotification>> _groupNotifications(
      List<DatedashNotification> notifications, LanguageProvider lp) {
    final Map<String, List<DatedashNotification>> groups = {
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));

    for (var n in notifications) {
      final DateTime nDate =
          DateTime(n.timestamp.year, n.timestamp.month, n.timestamp.day);
      if (nDate == today) {
        groups['Today']!.add(n);
      } else if (nDate == yesterday) {
        groups['Yesterday']!.add(n);
      } else {
        groups['Earlier']!.add(n);
      }
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final lp = context.watch<LanguageProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final isPremium = profileProvider.userProfile?.isPremium ?? false;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(lp.getString('signin_to_view_messages'))),
      );
    }

    if (!isPremium) {
      return Scaffold(
        body: Stack(
          children: [
            // Blurred background (optional, could just be a nice gradient)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor,
                    Theme.of(context).colorScheme.primary.withValues(alpha: 	0.05),
                  ],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4D85).withValues(alpha: 	0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Iconsax.notification_bing,
                        size: 64,
                        color: Color(0xFFFF4D85),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Premium Feature',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Notifications are available to premium members only. Upgrade to see who is interacting with your profile!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).hintColor,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        profileProvider.navigateToPremium(0);
                        Navigator.pop(context); // Go back to LandingScreen to see the Premium tab
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D85),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Go Premium',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Lock icon overlay
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 	0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.lock, size: 20, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: StreamBuilder<List<DatedashNotification>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF4D85)));
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) return _buildEmptyState(context, lp);

          final grouped = _groupNotifications(notifications, lp);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Text(
                    lp.getString('notifications'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        _notificationService.markAllAsRead(user.uid),
                    child: Text(lp.getString('mark_all_read'),
                        style: const TextStyle(
                            color: Color(0xFFFF4D85),
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              if (grouped['Today']!.isNotEmpty)
                _buildSectionHeader(lp.getString('today')),
              if (grouped['Today']!.isNotEmpty)
                _buildNotificationSliver(grouped['Today']!),
              if (grouped['Yesterday']!.isNotEmpty)
                _buildSectionHeader(lp.getString('yesterday')),
              if (grouped['Yesterday']!.isNotEmpty)
                _buildNotificationSliver(grouped['Yesterday']!),
              if (grouped['Earlier']!.isNotEmpty)
                _buildSectionHeader(lp.getString('earlier')),
              if (grouped['Earlier']!.isNotEmpty)
                _buildNotificationSliver(grouped['Earlier']!),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildNotificationSliver(List<DatedashNotification> items) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _NotificationCard(
            notification: items[index],
            service: _notificationService,
            profileService: _profileService,
            onPop: () => setState(() {}),
          ),
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, LanguageProvider lp) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D85).withValues(alpha: 	0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.notification_bing,
                size: 80, color: Color(0xFFFF4D85)),
          ),
          const SizedBox(height: 24),
          Text(
            lp.getString('no_notifications_title'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            lp.getString('no_notifications_sub'),
            style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatefulWidget {
  final DatedashNotification notification;
  final NotificationService service;
  final ProfileService profileService;
  final VoidCallback onPop;

  const _NotificationCard({
    required this.notification,
    required this.service,
    required this.profileService,
    required this.onPop,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  late Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    // Only fetch profile if it's not a system/reward notification
    if (widget.notification.senderId != 'system' &&
        widget.notification.type != 'reward') {
      _profileFuture =
          widget.profileService.getUserProfile(widget.notification.senderId);
    } else {
      _profileFuture = Future.value(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLike = widget.notification.type == 'like';
    final bool isMatch = widget.notification.type == 'match';
    final bool isMissedCall = widget.notification.type == 'missed_call';
    final bool isGift = widget.notification.type == 'gift';
    final bool isReward = widget.notification.type == 'reward';
    final bool isBooking = widget.notification.type.startsWith('booking_');
    final lp = context.watch<LanguageProvider>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _handleTap(context, lp),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.notification.isRead
                ? Colors.transparent
                : const Color(0xFFFF4D85).withValues(alpha: 	0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.notification.isRead
                  ? Colors.grey.withValues(alpha: 	0.08)
                  : const Color(0xFFFF4D85).withValues(alpha: 	0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              _buildAvatar(context),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 15),
                        children: [
                          TextSpan(
                              text: widget.notification.senderName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(
                              text: isLike
                                  ? ' ${lp.getString('liked_profile_suffix')}'
                                  : isMatch
                                      ? ' matched with you! 🎉'
                                      : isMissedCall
                                          ? ' ${lp.getString('missed_call_suffix')}'
                                          : isGift
                                              ? ' ${lp.getString('received_gift_suffix')}'
                                              : isReward
                                                  ? '' // Rewards already have full message
                                                  : isBooking
                                                      ? (widget.notification.type ==
                                                              'booking_request'
                                                          ? ' proposed a date!'
                                                          : widget.notification
                                                                      .type ==
                                                                  'booking_accepted'
                                                              ? ' accepted your date proposal!'
                                                              : ' declined your date proposal.')
                                                      : ' ${lp.getString('viewed_profile_suffix')}'),
                        ],
                      ),
                    ),
                    if (widget.notification.message != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.notification.message!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF4D85),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _formatDateTime(widget.notification.timestamp, lp),
                      style: TextStyle(
                        color:
                            Theme.of(context).hintColor.withValues(alpha: 	0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.notification.isRead)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4D85),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Color(0xFFFF4D85),
                          blurRadius: 6,
                          spreadRadius: 1)
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final bool isLike = widget.notification.type == 'like';
    final bool isMatch = widget.notification.type == 'match';
    final bool isMissedCall = widget.notification.type == 'missed_call';
    final bool isGift = widget.notification.type == 'gift';
    final bool isReward = widget.notification.type == 'reward';
    final bool isBooking = widget.notification.type.startsWith('booking_');
 
    final IconData icon = isLike
        ? Iconsax.heart5
        : isMatch
            ? Iconsax.heart_tick
            : isMissedCall
                ? Iconsax.call_slash
                : isGift
                    ? Iconsax.gift
                    : isReward
                        ? Iconsax.wallet_3
                        : isBooking
                            ? Iconsax.calendar
                            : Iconsax.eye;
    final Color badgeColor = isLike
        ? const Color(0xFFFF4D85)
        : isMatch
            ? Colors.green
            : isMissedCall
                ? Colors.red
                : isGift
                    ? Colors.amber
                    : isReward
                        ? Colors.orangeAccent
                        : isBooking
                            ? Colors.orange
                            : Colors.blue;

    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final photo =
            profile?.photos.isNotEmpty == true ? profile!.photos.first : null;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2),
                image: photo != null
                    ? DecorationImage(
                        image: NetworkImage(photo), fit: BoxFit.cover)
                    : null,
              ),
              child: photo == null
                  ? const Icon(Iconsax.user, size: 24, color: Colors.grey)
                  : null,
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2),
                ),
                child: Icon(icon, color: Colors.white, size: 10),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime, LanguageProvider lp) {
    return DateFormatter.format(dateTime, lp);
  }

  void _handleTap(BuildContext context, LanguageProvider lp) async {
    widget.service.markAsRead(widget.notification.id);
    widget.onPop();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF4D85)),
      ),
    );

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Use the cached future instead of starting a new fetch
      final senderProfile =
          await _profileFuture.timeout(const Duration(seconds: 10));

      if (mounted) {
        // Pop the loading dialog specifically
        navigator.pop();

        if (senderProfile != null) {
          if (!mounted) return;
          // ignore: use_build_context_synchronously
          _showProfileDetails(context, senderProfile, lp);
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(lp.getString('swipes_reset_failed'))),
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
      if (mounted) {
        // Pop the loading dialog if it's still there
        navigator.pop();
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(lp.getString('swipes_reset_failed'))),
        );
      }
    }
  }

  void _showProfileDetails(
      BuildContext context, UserProfile profile, LanguageProvider lp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileDetailSheet(
        profile: profile,
        onLike: () async {
          final profileProvider = context.read<ProfileProvider>();
          final myUid = profileProvider.currentUser?.uid;
          if (myUid != null && profile.uid != null) {
            final isMatch = await widget.profileService.swipeUser(
                myUid, profile.uid!, 'like',
                senderName: profileProvider.displayName);
            if (isMatch && context.mounted) {
              _showMatchDialog(context, profile);
            }
          }
          if (context.mounted) Navigator.pop(context);
        },
        onDislike: () async {
          final profileProvider = context.read<ProfileProvider>();
          final myUid = profileProvider.currentUser?.uid;
          if (myUid != null && profile.uid != null) {
            await widget.profileService.swipeUser(
                myUid, profile.uid!, 'dislike',
                senderName: profileProvider.displayName);
          }
          if (context.mounted) Navigator.pop(context);
        },
        onMessage: () async {
          final myUid = FirebaseAuth.instance.currentUser?.uid;
          if (myUid == null || profile.uid == null) return;
          Navigator.pop(context);
          if (context.mounted) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChatScreen(
                          otherUserId: profile.uid!,
                          otherUserName: profile.firstName ??
                              lp.getString('user_fallback'),
                          otherUserPhoto: profile.photos.isNotEmpty
                              ? profile.photos.first
                              : null,
                        )));
          }
        },
      ),
    );
  }

  void _showMatchDialog(BuildContext context, UserProfile otherProfile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: const Color(0xFFFF4D85).withValues(alpha: 	0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D85).withValues(alpha: 	0.15),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'IT\'S A MATCH!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFF4D85),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You and ${otherProfile.firstName} liked each other.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // My Avatar
                  Consumer<ProfileProvider>(
                    builder: (context, provider, _) {
                      final myPhoto = provider.userProfile?.photos.isNotEmpty == true
                          ? provider.userProfile!.photos.first
                          : null;
                      return Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          image: myPhoto != null
                              ? DecorationImage(image: NetworkImage(myPhoto), fit: BoxFit.cover)
                              : null,
                        ),
                        child: myPhoto == null ? const Icon(Icons.person, color: Colors.white, size: 45) : null,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  const Icon(Iconsax.heart5, color: Color(0xFFFF4D85), size: 36),
                  const SizedBox(width: 12),
                  // Other User Avatar
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      image: otherProfile.photos.isNotEmpty
                          ? DecorationImage(image: NetworkImage(otherProfile.photos.first), fit: BoxFit.cover)
                          : null,
                    ),
                    child: otherProfile.photos.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 45) : null,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        otherUserId: otherProfile.uid!,
                        otherUserName: otherProfile.firstName ?? 'User',
                        otherUserPhoto: otherProfile.photos.isNotEmpty ? otherProfile.photos.first : null,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D85),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text(
                  'SEND A MESSAGE',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'NOT NOW',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 	0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
