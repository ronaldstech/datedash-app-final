import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../models/user_profile_model.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    context.watch<LanguageProvider>();
    final profile = profileProvider.userProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFFFF4D85);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }



    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D0D11) : const Color(0xFFF7F7F9),
      body: CustomScrollView(
        slivers: [
          // ── Premium Header ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? Colors.black : primaryColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Iconsax.arrow_left_2, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'CHALLENGES',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 2,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF4D85), Color(0xFFFF8E8E)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      Iconsax.cup5,
                      size: 150,
                      color: Colors.white.withValues(alpha: 	0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Dashboard ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(profile, isDark),
                  const SizedBox(height: 32),
                  _buildSectionTitle('ACTIVE CHALLENGES'),
                  const SizedBox(height: 16),

                  // Challenge 0: Daily Messenger (Allowance)
                  _ChallengeCard(
                    id: 'daily_messenger',
                    title: 'Daily Messenger',
                    description: 'Daily allowance of 5 free messages',
                    reward: 0,
                    progress: ((profile.dailyMessageCount) / 5).clamp(0.0, 1.0),
                    progressLabel: '${profile.dailyMessageCount} / 5',
                    isCompleted: profile.dailyMessageCount >= 5,
                    isClaimed: false,
                    icon: Iconsax.message_text,
                    accentColor: Colors.orangeAccent,
                  ),

                  const SizedBox(height: 16),

                  // Challenge 1: Daily Explorer
                  _ChallengeCard(
                    id: 'daily_explorer',
                    title: 'Daily Explorer',
                    description: 'Use Datedash for 3 hours today',
                    reward: 50,
                    progress:
                        (profile.dailyUsageDuration / 10800).clamp(0.0, 1.0),
                    progressLabel:
                        '${(profile.dailyUsageDuration / 3600).toStringAsFixed(1)}h / 3h',
                    isCompleted: profile.dailyUsageDuration >= 10800,
                    isClaimed: profile.claimedRewards.contains('daily_explorer'),
                    icon: Iconsax.timer_1,
                    accentColor: Colors.blueAccent,
                  ),

                  const SizedBox(height: 16),

                  // Challenge 2: Profile Pro
                  _ChallengeCard(
                    id: 'profile_pro',
                    title: 'Profile Pro',
                    description: 'Complete 100% of your profile',
                    reward: 100,
                    progress: profile.completionPercentage / 100,
                    progressLabel: '${profile.completionPercentage}%',
                    isCompleted: profile.completionPercentage >= 100,
                    isClaimed: profile.claimedRewards.contains('profile_pro'),
                    icon: Iconsax.user_edit,
                    accentColor: Colors.purpleAccent,
                  ),

                  const SizedBox(height: 16),

                  // Challenge 3: Trusted Member
                  _ChallengeCard(
                    id: 'trusted_member',
                    title: 'Trusted Member',
                    description: 'Verify your account',
                    reward: 50,
                    progress: profile.isVerified ? 1.0 : 0.0,
                    progressLabel:
                        profile.isVerified ? 'Verified' : 'Not Verified',
                    isCompleted: profile.isVerified,
                    isClaimed:
                        profile.claimedRewards.contains('trusted_member'),
                    icon: Iconsax.verify,
                    accentColor: Colors.tealAccent,
                  ),

                  const SizedBox(height: 16),

                  // Challenge 4: Welcome Bonus
                  const _ChallengeCard(
                    id: 'welcome_bonus',
                    title: 'Welcome Gift',
                    description: 'Join the Datedash community',
                    reward: 50,
                    progress: 1.0,
                    progressLabel: 'Completed',
                    isCompleted: true,
                    isClaimed:
                        true, // Existing users already have this or it's handled at signup
                    icon: Iconsax.cake,
                    accentColor: Colors.orangeAccent,
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(UserProfile profile, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 	0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 	0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Credits', profile.credits.toString(),
              Iconsax.wallet_3, Colors.orangeAccent),
          Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 	0.2)),
          _buildStatItem('Claimed', profile.claimedRewards.length.toString(),
              Iconsax.receipt_21, const Color(0xFFFF4D85)),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Colors.grey,
      ),
    );
  }
}

class _ChallengeCard extends StatefulWidget {
  final String id;
  final String title;
  final String description;
  final int reward;
  final double progress;
  final String progressLabel;
  final bool isCompleted;
  final bool isClaimed;
  final IconData icon;
  final Color accentColor;

  const _ChallengeCard({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    required this.progress,
    required this.progressLabel,
    required this.isCompleted,
    required this.isClaimed,
    required this.icon,
    required this.accentColor,
  });

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  bool _isClaiming = false;

  Future<void> _handleClaim(BuildContext context) async {
    setState(() => _isClaiming = true);
    try {
      await context
          .read<ProfileProvider>()
          .claimReward(widget.id, widget.reward);
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Succesfully claimed ${widget.reward} credits!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canClaim = widget.isCompleted && !widget.isClaimed;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 	0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: canClaim
              ? widget.accentColor.withValues(alpha: 	0.5)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 	0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: widget.accentColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        widget.description,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (widget.reward > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 	0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+${widget.reward}',
                      style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: widget.progress,
                      backgroundColor: Colors.grey.withValues(alpha: 	0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isClaimed ? Colors.green : widget.accentColor,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.progressLabel,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canClaim && !_isClaiming
                    ? () => _handleClaim(context)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canClaim
                      ? widget.accentColor
                      : (widget.isClaimed
                          ? Colors.green.withValues(alpha: 	0.1)
                          : Colors.grey.withValues(alpha: 	0.1)),
                  foregroundColor: canClaim
                      ? Colors.white
                      : (widget.isClaimed ? Colors.green : Colors.grey),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isClaiming
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        widget.isClaimed
                            ? 'CLAIMED'
                            : (widget.isCompleted
                                ? (widget.reward > 0 ? 'CLAIM REWARD' : 'LIMIT REACHED')
                                : (widget.reward > 0 ? 'IN PROGRESS' : 'FREE USAGE')),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

