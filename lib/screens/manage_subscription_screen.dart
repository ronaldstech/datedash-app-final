import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../models/user_profile_model.dart';
import '../providers/profile_provider.dart';
import '../screens/premium_screen.dart';

class ManageSubscriptionScreen extends StatefulWidget {
  const ManageSubscriptionScreen({super.key});

  @override
  State<ManageSubscriptionScreen> createState() =>
      _ManageSubscriptionScreenState();
}

class _ManageSubscriptionScreenState extends State<ManageSubscriptionScreen> {
  bool _isProcessing = false;
  int? _activatingPlanIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        final profile = profileProvider.userProfile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Manage Subscription')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final bool isPremium = profile.isPremium;
        final DateTime? expiry = profile.premiumExpiry;
        final DateTime? purchasedAt = profile.premiumPurchasedAt;
        final bool isExpired = expiry != null && DateTime.now().isAfter(expiry);
        final bool isActive = isPremium && !isExpired;
        final String rawPlan = profile.premiumType?.trim() ?? 'Free';
        final String planUpper = rawPlan.toUpperCase();

        // Theme colors based on plan
        Color planAccentColor = const Color(0xFFFFB300); // Standard Gold/Amber
        Color planGradientEnd = const Color(0xFFFF8F00);
        IconData planIcon = Iconsax.star5;

        if (planUpper.contains('ELITE')) {
          planAccentColor = const Color(0xFFB388FF);
          planGradientEnd = const Color(0xFF7C4DFF);
          planIcon = Iconsax.crown5;
        } else if (planUpper.contains('PRO')) {
          planAccentColor = const Color(0xFF29B6F6);
          planGradientEnd = const Color(0xFF0288D1);
          planIcon = Iconsax.flash_15;
        } else if (planUpper.contains('PREMIUM')) {
          planAccentColor = const Color(0xFFFF4D85);
          planGradientEnd = const Color(0xFFFF7597);
          planIcon = Iconsax.star5;
        } else if (!isActive) {
          planAccentColor = const Color(0xFF9E9E9E);
          planGradientEnd = const Color(0xFF757575);
          planIcon = Iconsax.lock;
        }

        // Time remaining calculations
        String remainingText = 'No active period';
        double progress = 1.0;
        if (isActive && expiry != null) {
          final remaining = expiry.difference(DateTime.now());
          if (remaining.inDays > 1) {
            remainingText = '${remaining.inDays} days remaining';
          } else if (remaining.inHours > 0) {
            remainingText =
                '${remaining.inHours}h ${remaining.inMinutes % 60}m remaining';
          } else if (remaining.inMinutes > 0) {
            remainingText = '${remaining.inMinutes} minutes remaining';
          } else {
            remainingText = 'Expiring in less than a minute';
          }

          if (purchasedAt != null) {
            final totalDuration = expiry.difference(purchasedAt).inSeconds;
            final elapsed = DateTime.now().difference(purchasedAt).inSeconds;
            if (totalDuration > 0) {
              progress = (1.0 - (elapsed / totalDuration)).clamp(0.0, 1.0);
            }
          }
        }

        final bool isMonthly =
            profile.isPlanMonthly ||
            (expiry != null &&
                purchasedAt != null &&
                expiry.difference(purchasedAt).inDays >= 25);

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF0F0F14)
              : const Color(0xFFF8F9FD),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Subscription & Plan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
          ),
          body: _isProcessing
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFFF4D85)),
                      SizedBox(height: 16),
                      Text(
                        'Updating membership...',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Plan Hero Card
                      _buildHeroCard(
                        context: context,
                        isDark: isDark,
                        isActive: isActive,
                        isExpired: isExpired,
                        planName: isActive
                            ? rawPlan.toUpperCase()
                            : 'FREE TIER',
                        isMonthly: isMonthly,
                        planIcon: planIcon,
                        planAccentColor: planAccentColor,
                        planGradientEnd: planGradientEnd,
                        remainingText: remainingText,
                        progress: progress,
                        purchasedAt: purchasedAt,
                        expiry: expiry,
                      ),

                      const SizedBox(height: 24),

                      // Plan Benefits Section
                      _buildBenefitsSection(
                        context: context,
                        isDark: isDark,
                        isActive: isActive,
                        planUpper: planUpper,
                        accentColor: planAccentColor,
                      ),

                      const SizedBox(height: 24),

                      // Queued Subscriptions Section (if any)
                      if (profile.queuedSubscriptions.isNotEmpty) ...[
                        _buildQueuedSection(
                          context: context,
                          isDark: isDark,
                          profile: profile,
                          profileProvider: profileProvider,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Actions Section (Upgrade / Cancel)
                      _buildActionButtons(
                        context: context,
                        isDark: isDark,
                        isActive: isActive,
                        rawPlan: rawPlan,
                        profileProvider: profileProvider,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // Hero Card with active status, dates, and progress indicator
  Widget _buildHeroCard({
    required BuildContext context,
    required bool isDark,
    required bool isActive,
    required bool isExpired,
    required String planName,
    required bool isMonthly,
    required IconData planIcon,
    required Color planAccentColor,
    required Color planGradientEnd,
    required String remainingText,
    required double progress,
    required DateTime? purchasedAt,
    required DateTime? expiry,
  }) {
    final emeraldGreen = const Color(0xFF00C853);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181822) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isActive
              ? planAccentColor.withValues(alpha: 0.4)
              : (isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.06)),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? planAccentColor.withValues(alpha: isDark ? 0.2 : 0.12)
                : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Plan Icon, Badge, and Status Tag
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isActive
                    ? [
                        planAccentColor.withValues(alpha: 0.15),
                        planGradientEnd.withValues(alpha: 0.04),
                      ]
                    : [
                        isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.grey.shade100,
                        isDark
                            ? Colors.white.withValues(alpha: 0.01)
                            : Colors.grey.shade50,
                      ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(
                            colors: [planAccentColor, planGradientEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isActive
                        ? null
                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                    shape: BoxShape.circle,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: planAccentColor.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    planIcon,
                    color: isActive
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black54),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isActive ? '$planName PASS' : 'FREE ACCOUNT',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isActive
                                          ? emeraldGreen
                                          : (isExpired
                                                ? const Color(0xFFFF5252)
                                                : Colors.grey))
                                      .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    (isActive
                                            ? emeraldGreen
                                            : (isExpired
                                                  ? const Color(0xFFFF5252)
                                                  : Colors.grey))
                                        .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isActive)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(right: 5),
                                    decoration: BoxDecoration(
                                      color: emeraldGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Text(
                                  isActive
                                      ? 'ACTIVE'
                                      : (isExpired ? 'EXPIRED' : 'STANDARD'),
                                  style: TextStyle(
                                    color: isActive
                                        ? emeraldGreen
                                        : (isExpired
                                              ? const Color(0xFFFF5252)
                                              : Colors.grey),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isActive
                            ? (isMonthly
                                  ? 'Monthly Subscription'
                                  : 'Weekly Subscription')
                            : 'Standard free access tier',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).hintColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isActive && expiry != null) ...[
                  // Remaining time indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Iconsax.clock, size: 16, color: planAccentColor),
                          const SizedBox(width: 6),
                          Text(
                            remainingText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: planAccentColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${(progress * 100).toInt()}% left',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: planAccentColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        planAccentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Date breakdown list
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDateRow(
                        icon: Iconsax.calendar_tick,
                        label: 'Activated On',
                        value: purchasedAt != null
                            ? _formatDate(purchasedAt)
                            : 'Unknown',
                        isDark: isDark,
                        context: context,
                      ),
                      const SizedBox(height: 10),
                      _buildDateRow(
                        icon: Iconsax.timer_1,
                        label: 'Expires / Renews',
                        value: expiry != null ? _formatDate(expiry) : 'Never',
                        isDark: isDark,
                        context: context,
                        isHighlight: isActive,
                        highlightColor: planAccentColor,
                      ),
                      const SizedBox(height: 10),
                      _buildDateRow(
                        icon: Iconsax.shield_tick,
                        label: 'Access Level',
                        value: isActive ? 'Full VIP Access' : 'Standard Tier',
                        isDark: isDark,
                        context: context,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required BuildContext context,
    bool isHighlight = false,
    Color? highlightColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: Theme.of(context).hintColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isHighlight
                ? (highlightColor ?? const Color(0xFFFF4D85))
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  // Benefits & Privileges section
  Widget _buildBenefitsSection({
    required BuildContext context,
    required bool isDark,
    required bool isActive,
    required String planUpper,
    required Color accentColor,
  }) {
    List<String> benefits;
    if (planUpper.contains('ELITE')) {
      benefits = [
        'Unlimited Likes & Rewind swipes',
        'Unlimited Direct Messages with everyone',
        'Unlimited HD Video & Voice calls',
        '2 Free Profile Boosts per week',
        '2,000 Free Sparks bonus',
        'Instant Match on Likes (See who likes you)',
        'Unlock Profile Lock & Hide Age privacy options',
        'Priority VIP discovery & 2x more visibility',
      ];
    } else if (planUpper.contains('PRO')) {
      benefits = [
        'Unlimited Likes & Rewind swipes',
        'Unlimited Messages with matches',
        'Unlimited Voice Calls',
        '2x more profile views',
        'Extended Filters & Looking For preferences',
        'See everyone\'s online status',
      ];
    } else if (planUpper.contains('PREMIUM')) {
      benefits = [
        'Unlimited Likes & Rewind swipes',
        'Unlimited Messages with matches',
        'Unlimited HD Video & Voice calls',
        '1 Free Profile Boost per week',
        'See missed matches & full match list',
        'Extended Discovery Filters',
        '2x more profile views',
      ];
    } else {
      // Free account benefits / highlights
      benefits = [
        'Standard profile creation & photo uploads',
        'Daily free swiping allowance',
        'Basic messaging with mutual matches',
      ];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181822) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.verify, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text(
                isActive ? 'Your Plan Privileges' : 'Current Tier Privileges',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...benefits.map((benefit) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: (isActive ? accentColor : Colors.grey).withValues(
                        alpha: 0.15,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 11,
                      color: isActive ? accentColor : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      benefit,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Queued subscriptions section
  Widget _buildQueuedSection({
    required BuildContext context,
    required bool isDark,
    required UserProfile profile,
    required ProfileProvider profileProvider,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181822) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF29B6F6).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.hierarchy, size: 18, color: Color(0xFF29B6F6)),
              const SizedBox(width: 8),
              Text(
                'Queued Memberships (${profile.queuedSubscriptions.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF29B6F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'These memberships are preserved and will activate automatically, or you can switch to one now.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).hintColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          ...profile.queuedSubscriptions.asMap().entries.map((entry) {
            final index = entry.key;
            final q = entry.value;
            final qPlan = q['plan']?.toString() ?? 'Premium';
            final qMonthly = q['isMonthly'] == true;
            final qDays = (q['days'] as num?)?.toInt() ?? (qMonthly ? 30 : 7);
            final isActivatingThis = _activatingPlanIndex == index;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${qPlan.toUpperCase()} PASS',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$qDays days preserved • ${qMonthly ? "Monthly" : "Weekly"}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).hintColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isActivatingThis)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF4D85),
                      ),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Switch / Activate button
                        InkWell(
                          onTap: () => _confirmSwitchQueued(
                            context,
                            profile,
                            q,
                            index,
                            profileProvider,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4D85), Color(0xFFFF8DA1)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Switch',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Remove button
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onPressed: () => _confirmRemoveQueued(
                            context,
                            index,
                            qPlan,
                            profileProvider,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Action buttons: Upgrade & Cancel
  Widget _buildActionButtons({
    required BuildContext context,
    required bool isDark,
    required bool isActive,
    required String rawPlan,
    required ProfileProvider profileProvider,
  }) {
    return Column(
      children: [
        // Upgrade / Change Plan Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PremiumScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D85),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.flash_1, size: 18),
                const SizedBox(width: 8),
                Text(
                  isActive ? 'Change or Upgrade Tier' : 'Upgrade to Premium',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Cancel Membership Button (only shown if user has active plan or queued plans)
        if (isActive ||
            (profileProvider.userProfile?.queuedSubscriptions.isNotEmpty ==
                true)) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => _showCancelConfirmationSheet(
                context: context,
                isDark: isDark,
                planName: rawPlan,
                profileProvider: profileProvider,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF5252),
                side: BorderSide(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.close_circle, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Cancel Membership',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Confirmation bottom sheet for cancellation
  Future<void> _showCancelConfirmationSheet({
    required BuildContext context,
    required bool isDark,
    required String planName,
    required ProfileProvider profileProvider,
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E26) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Danger Warning Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.warning_2,
                  color: Color(0xFFFF5252),
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'Cancel $planName Membership?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              Text(
                'Are you sure you want to cancel your membership? You will immediately lose all premium privileges and return to the standard Free tier.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(sheetContext).hintColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // What you'll lose list
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    _buildLossItem('Unlimited likes & rewind swipes'),
                    const SizedBox(height: 8),
                    _buildLossItem('HD video & voice calling privileges'),
                    const SizedBox(height: 8),
                    _buildLossItem(
                      'Priority VIP matching & profile visibility',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Button row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                      ),
                      child: const Text(
                        'Keep Plan',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5252),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Yes, Cancel',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final messenger = ScaffoldMessenger.of(context);
      try {
        await profileProvider.cancelSubscription(
          clearQueuedSubscriptions: true,
        );
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF1E1E26),
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF00C853), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your membership has been cancelled successfully.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFFF5252),
              content: Text('Failed to cancel membership: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  Widget _buildLossItem(String text) {
    return Row(
      children: [
        const Icon(Icons.close, color: Color(0xFFFF5252), size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // Switch queued plan confirmation
  Future<void> _confirmSwitchQueued(
    BuildContext context,
    UserProfile currentProfile,
    Map<String, dynamic> selectedPlan,
    int index,
    ProfileProvider profileProvider,
  ) async {
    final newPlanName = selectedPlan['plan']?.toString() ?? 'Premium';
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Switch to $newPlanName?'),
        content: Text(
          'This will activate $newPlanName right away. Your current plan will be placed into the queue with remaining days preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D85),
              foregroundColor: Colors.white,
            ),
            child: const Text('Activate Now'),
          ),
        ],
      ),
    );

    if (shouldProceed == true && mounted) {
      setState(() => _activatingPlanIndex = index);
      final messenger = ScaffoldMessenger.of(context);
      try {
        await profileProvider.switchQueuedSubscription(selectedPlan, index);
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('$newPlanName Membership activated!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error activating plan: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _activatingPlanIndex = null);
        }
      }
    }
  }

  // Remove queued plan confirmation
  Future<void> _confirmRemoveQueued(
    BuildContext context,
    int index,
    String planName,
    ProfileProvider profileProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove $planName from Queue?'),
        content: const Text(
          'Are you sure you want to remove this queued membership? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(
                color: Color(0xFFFF5252),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await profileProvider.removeQueuedSubscription(index);
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Queued subscription removed'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error removing queued subscription: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute';
  }
}
