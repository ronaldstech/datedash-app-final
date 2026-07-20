import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key});

  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  final NotificationService _notificationService = NotificationService();
  final ProfileService _profileService = ProfileService();

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final lp = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFFFF4D85);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D0D11) : const Color(0xFFF7F7F9),
      body: CustomScrollView(
        slivers: [
          // Premium Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? Colors.black : primaryColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Iconsax.arrow_left_2, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Abstract Background Pattern
                  Positioned(
                    right: -50,
                    top: -20,
                    child: Icon(
                      Iconsax.gift5,
                      size: 200,
                      color: Colors.white.withValues(alpha: 	0.1),
                    ),
                  ),
                  _buildHeaderContent(profileProvider, lp),
                ],
              ),
            ),
          ),

          // Gifts List
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  const Icon(Iconsax.clock, size: 20, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text(
                    'REWARD HISTORY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.grey.withValues(alpha: 	0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (profileProvider.currentUser != null)
            StreamBuilder<List<DatedashNotification>>(
              stream: _notificationService
                  .getNotificationsStream(profileProvider.currentUser!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFFF4D85))),
                  );
                }

                // Filter for gifts and rewards
                final items = (snapshot.data ?? [])
                    .where((n) => n.type == 'gift' || n.type == 'reward')
                    .toList();

                if (items.isEmpty) {
                  return _buildEmptyState(lp, isDark);
                }

                return SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _GiftRewardCard(
                        notification: items[index],
                        profileService: _profileService,
                      ),
                      childCount: items.length,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderContent(ProfileProvider pp, LanguageProvider lp) {
    final credits = pp.userProfile?.credits ?? 0;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF4D85), Color(0xFFFF8E8E)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 	0.2),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Iconsax.wallet_3, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 12),
            Text(
              credits.toString().replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            Text(
              'TOTAL CREDITS RECEIVED',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 	0.8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider lp, bool isDark) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 	0.05)
                    : Colors.black.withValues(alpha: 	0.03),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.gift, size: 64, color: Colors.blueGrey),
            ),
            const SizedBox(height: 24),
            const Text(
              'No rewards yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Receive gifts from other users or complete daily activity to earn rewards!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftRewardCard extends StatelessWidget {
  final DatedashNotification notification;
  final ProfileService profileService;

  const _GiftRewardCard({
    required this.notification,
    required this.profileService,
  });

  @override
  Widget build(BuildContext context) {
    final isReward = notification.type == 'reward';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr =
        DateFormat('MMM dd, yyyy • hh:mm a').format(notification.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 	0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 	0.05)
              : Colors.black.withValues(alpha: 	0.03),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: (isReward ? Colors.orangeAccent : const Color(0xFFFF4D85))
                .withValues(alpha: 	0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isReward ? Iconsax.wallet_3 : Iconsax.gift,
            color: isReward ? Colors.orangeAccent : const Color(0xFFFF4D85),
            size: 24,
          ),
        ),
        title: Text(
          isReward ? 'Daily Activity Reward' : 'Gift Received',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message ??
                  (isReward ? '+50 Credits' : 'You received a gift!'),
              style: TextStyle(
                color: isReward
                    ? Colors.orangeAccent
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: isReward ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: isReward
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 	0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '+50',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

