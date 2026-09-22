import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snellum/providers/profile_provider.dart';
import 'package:snellum/screens/premium_screen.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/user_profile_model.dart';
import '../services/profile_service.dart';
import '../providers/language_provider.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'likes_screen.dart';
import 'profile_viewers_screen.dart';
import '../widgets/boost_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  bool _isLoading = true;
  UserProfile _profile = UserProfile.empty();
  final Color _primaryColor = const Color(0xFFFF4D85);
  final User? _user = FirebaseAuth.instance.currentUser;
  int? _activatingPlanIndex;

  Future<void> _activateQueuedPlan(
    UserProfile currentProfile,
    Map<String, dynamic> selectedPlan,
    int index,
  ) async {
    final uid = _user?.uid;
    if (uid == null) return;

    final newPlanName = selectedPlan['plan']?.toString() ?? 'Premium';
    final currentPlanName = currentProfile.premiumType ?? 'Premium';

    // Show confirmation dialog before swapping
    final shouldProceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final isDarkMode = Theme.of(modalCtx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D85).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.crown,
                  color: Color(0xFFFF4D85),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Activate $newPlanName Membership',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'This will make $newPlanName your active membership. Your current $currentPlanName plan will be safely queued with its remaining time preserved.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(modalCtx).hintColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(modalCtx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(
                          color: isDarkMode ? Colors.white24 : Colors.black12,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(modalCtx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D85),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Activate Now',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

    if (shouldProceed != true) return;

    setState(() => _activatingPlanIndex = index);

    try {
      final now = DateTime.now();

      // 1. Calculate remaining days/duration on the current active plan to preserve in queued list
      final currentExpiry = currentProfile.premiumExpiry;
      int remainingDays = 0;
      if (currentExpiry != null && currentExpiry.isAfter(now)) {
        remainingDays = currentExpiry.difference(now).inDays;
        if (remainingDays < 1) remainingDays = 1;
      } else {
        remainingDays = (currentProfile.isPlanMonthly == true) ? 30 : 7;
      }

      final demotedPlan = <String, dynamic>{
        'plan': currentProfile.premiumType ?? 'Premium',
        'isMonthly': currentProfile.isPlanMonthly == true,
        'days': remainingDays,
        'purchasedAt': currentProfile.premiumPurchasedAt != null
            ? Timestamp.fromDate(currentProfile.premiumPurchasedAt!)
            : Timestamp.fromDate(now),
      };

      // 2. Prepare new active plan info
      final isNewMonthly = selectedPlan['isMonthly'] == true;
      final newDays = (selectedPlan['days'] as num?)?.toInt() ?? (isNewMonthly ? 30 : 7);
      final newExpiry = now.add(Duration(days: newDays));

      // 3. New queued subscriptions = (old queue minus selected item) + demotedPlan
      final updatedQueue = List<Map<String, dynamic>>.from(
        currentProfile.queuedSubscriptions.map((e) => Map<String, dynamic>.from(e)),
      );
      if (index >= 0 && index < updatedQueue.length) {
        updatedQueue.removeAt(index);
      }
      updatedQueue.add(demotedPlan);

      // 4. Update Firestore directly
      final updates = <String, dynamic>{
        'isPremium': true,
        'premiumType': newPlanName,
        'premiumExpiry': Timestamp.fromDate(newExpiry),
        'premiumPurchasedAt': selectedPlan['purchasedAt'] ?? Timestamp.fromDate(now),
        'isPlanMonthly': isNewMonthly,
        'queuedSubscriptions': updatedQueue,
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).update(updates);

      // Reload local profile
      await _loadProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('$newPlanName membership is now active!'),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error activating queued plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch membership: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _activatingPlanIndex = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    if (_user != null) {
      final existingProfile = await _profileService.getUserProfile(_user.uid);
      if (existingProfile != null) {
        _profile = existingProfile;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _navigateToEditScreen() async {
    // Navigate to the full editor and wait until it pops back
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
    // Reload data to reflect any changes and update percentage globally
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.getString('my_profile'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.arrow_left_2, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.setting_2, size: 18),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : RefreshIndicator(
              color: _primaryColor,
              onRefresh: _loadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  _buildProfileHeader(languageProvider, isDark),
                  const SizedBox(height: 20),
                  _buildSubscriptionStatusCard(languageProvider, isDark),
                  const SizedBox(height: 20),
                  _buildCompletionCard(languageProvider, isDark),
                  const SizedBox(height: 24),
                  _buildStatsGrid(languageProvider, isDark),
                  const SizedBox(height: 24),
                  _buildQuickActionMenu(languageProvider, isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(LanguageProvider languageProvider, bool isDark) {
    return Column(
      children: [
        GestureDetector(
          onTap: _navigateToEditScreen,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      _primaryColor,
                      const Color(0xFFFF8DAF),
                      const Color(0xFFFF2A6D),
                      _primaryColor,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withValues(
                        alpha: isDark ? 0.35 : 0.2,
                      ),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 64,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: _primaryColor.withValues(alpha: 0.1),
                    child: ClipOval(
                      child:
                          (_profile.photos.isNotEmpty ||
                              _user?.photoURL != null)
                          ? Image.network(
                              _profile.photos.isNotEmpty
                                  ? _profile.photos.first
                                  : _user!.photoURL!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _primaryColor,
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Iconsax.user,
                                  size: 48,
                                  color: _primaryColor,
                                );
                              },
                            )
                          : Icon(Iconsax.user, size: 48, color: _primaryColor),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, const Color(0xFFFF6584)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 3.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Iconsax.edit_2,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _profile.firstName ??
                  _user?.displayName ??
                  languageProvider.getString('welcome_back'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            if (_profile.isVerified) ...[
              const SizedBox(width: 6),
              const Icon(Iconsax.verify5, color: Color(0xFF2196F3), size: 22),
            ],
          ],
        ),
        if (_user?.email != null && _user!.email!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _user.email!,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (_profile.isPremium && _profile.premiumType != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF9E00)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9E00).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Iconsax.crown5, color: Colors.black, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_profile.premiumType!.toUpperCase()} MEMBER',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubscriptionStatusCard(
    LanguageProvider languageProvider,
    bool isDark,
  ) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        final profile = profileProvider.userProfile ?? _profile;
        final bool isPremium = profile.isPremium;
        final String planName =
            profile.premiumType?.toUpperCase() ?? 'FREE PLAN';
        final DateTime? expiry = profile.premiumExpiry;
        final DateTime? purchasedAt = profile.premiumPurchasedAt;
        final bool isExpired = expiry != null && DateTime.now().isAfter(expiry);
        final bool isActive = isPremium && !isExpired;

        // Calculate days / time remaining
        String remainingText = '';
        double progress = 1.0;
        if (isActive && expiry != null) {
          final remaining = expiry.difference(DateTime.now());
          if (remaining.inDays > 1) {
            remainingText = '${remaining.inDays} days remaining';
          } else if (remaining.inHours > 0) {
            remainingText = '${remaining.inHours} hours remaining';
          } else if (remaining.inMinutes > 0) {
            remainingText = '${remaining.inMinutes} mins remaining';
          } else {
            remainingText = 'Expiring soon';
          }

          if (purchasedAt != null) {
            final totalDuration = expiry.difference(purchasedAt).inSeconds;
            final elapsed = DateTime.now().difference(purchasedAt).inSeconds;
            if (totalDuration > 0) {
              progress = (1.0 - (elapsed / totalDuration)).clamp(0.0, 1.0);
            }
          }
        }

        String formatDate(DateTime dt) {
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

        final Color amberColor = const Color(0xFFFFB300);
        final Color greenColor = const Color(0xFF00C853);
        final Color purpleColor = const Color(0xFF9C27B0);

        Color planAccentColor = amberColor;
        if (planName.contains('ELITE')) {
          planAccentColor = purpleColor;
        } else if (planName.contains('PRO')) {
          planAccentColor = const Color(0xFF29B6F6);
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive
                  ? planAccentColor.withValues(alpha: 0.35)
                  : isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: isActive ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? planAccentColor.withValues(alpha: isDark ? 0.15 : 0.08)
                    : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Card Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? LinearGradient(
                                colors: [
                                  planAccentColor,
                                  planAccentColor.withValues(alpha: 0.7),
                                ],
                              )
                            : null,
                        color: isActive
                            ? null
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive ? Iconsax.crown5 : Iconsax.lock,
                        color: isActive
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black54),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isActive ? '$planName PASS' : 'FREE ACCOUNT',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: (isActive ? greenColor : Colors.grey)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isActive
                                      ? 'ACTIVE'
                                      : (isExpired ? 'EXPIRED' : 'STANDARD'),
                                  style: TextStyle(
                                    color: isActive ? greenColor : Colors.grey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Builder(builder: (context) {
                            final bool isMonthlyPlan = profile.isPlanMonthly ||
                                (expiry != null &&
                                    purchasedAt != null &&
                                    expiry.difference(purchasedAt).inDays >= 25) ||
                                (expiry != null &&
                                    expiry.difference(DateTime.now()).inDays >= 25);
                            return Text(
                              isActive
                                  ? (isMonthlyPlan
                                      ? 'Monthly Membership • $remainingText'
                                      : 'Weekly Membership • $remainingText')
                                  : 'Upgrade to unlock all VIP perks & boosts',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Active Subscription Details (Time Purchased, Time of Expiry, Progress Bar)
              if (isActive && expiry != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: planAccentColor.withValues(
                            alpha: 0.15,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            planAccentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Column(
                          children: [
                            if (purchasedAt != null) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Iconsax.calendar_tick,
                                        size: 14,
                                        color: Theme.of(context).hintColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Purchased on',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).hintColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    formatDate(purchasedAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Iconsax.timer_1,
                                      size: 14,
                                      color: Theme.of(context).hintColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Expires at',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).hintColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  formatDate(expiry),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        (expiry
                                                .difference(DateTime.now())
                                                .inDays <=
                                            2)
                                        ? const Color(0xFFFF5252)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // My Memberships (Manage / Switch Active Membership)
              if (profile.queuedSubscriptions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF29B6F6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF29B6F6).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Iconsax.crown,
                                  size: 14,
                                  color: Color(0xFF29B6F6),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'My Memberships (${profile.queuedSubscriptions.length + (isActive ? 1 : 0)})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF29B6F6),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Tap Activate to switch',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...profile.queuedSubscriptions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final q = entry.value;
                          final qPlan = q['plan']?.toString() ?? 'Premium';
                          final qMonthly = q['isMonthly'] == true;
                          final qDays =
                              (q['days'] as num?)?.toInt() ??
                              (qMonthly ? 30 : 7);
                          final isActivatingThis = _activatingPlanIndex == index;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: 0.04),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${qPlan.toUpperCase()} (${qMonthly ? "1 Month" : "$qDays Days"})',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Preserved in queue • $qDays days remaining',
                                        style: TextStyle(
                                          fontSize: 10,
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
                                  InkWell(
                                    onTap: _activatingPlanIndex != null
                                        ? null
                                        : () => _activateQueuedPlan(profile, q, index),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFF4D85),
                                            Color(0xFFFF8DA1),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFF4D85).withValues(alpha: 0.25),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Iconsax.flash_1,
                                            size: 11,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Activate',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Action button to Manage / Upgrade / Renew
              InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PremiumScreen(),
                    ),
                  );
                  _loadProfile();
                },
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? planAccentColor.withValues(alpha: 0.1)
                        : _primaryColor.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isActive
                            ? 'Manage or Upgrade Plan'
                            : 'Upgrade to Premium ⚡',
                        style: TextStyle(
                          color: isActive ? planAccentColor : _primaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Iconsax.arrow_right_3,
                        size: 14,
                        color: isActive ? planAccentColor : _primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletionCard(LanguageProvider languageProvider, bool isDark) {
    final bool isComplete = _profile.completionPercentage == 100;

    return GestureDetector(
      onTap: _navigateToEditScreen,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isComplete
                ? [const Color(0xFF2E7D32), const Color(0xFF4CAF50)]
                : [_primaryColor, const Color(0xFFFF7597)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: (isComplete ? Colors.green : _primaryColor).withValues(
                alpha: isDark ? 0.4 : 0.25,
              ),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: _profile.completionPercentage / 100,
                    strokeWidth: 5.5,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${_profile.completionPercentage}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isComplete
                        ? languageProvider.getString('profile_complete_title')
                        : languageProvider.getString('complete_your_profile'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isComplete
                        ? languageProvider.getString('tap_update_details')
                        : languageProvider.getString('matches_3x_likely'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.arrow_right_3,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(LanguageProvider languageProvider, bool isDark) {
    if (_user == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StreamBuilder<int>(
                stream: _profileService.getLikesCountStream(_user.uid),
                builder: (context, snapshot) {
                  return _buildStatCard(
                    icon: Iconsax.heart5,
                    title: languageProvider.getString('likes_label'),
                    value: snapshot.data?.toString() ?? '0',
                    color: const Color(0xFFFF3366),
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LikesScreen()),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: StreamBuilder<int>(
                stream: _profileService.getViewCountStream(_user.uid),
                builder: (context, snapshot) {
                  return _buildStatCard(
                    icon: Iconsax.eye,
                    title: languageProvider.getString('views_label'),
                    value: snapshot.data?.toString() ?? '0',
                    color: const Color(0xFF00C853),
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileViewersScreen(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Consumer<ProfileProvider>(
          builder: (context, profileProvider, _) {
            return _buildStatCard(
              icon: Iconsax.wallet_3,
              title: languageProvider.getString('my_credits'),
              value: profileProvider.userProfile?.credits.toString() ?? '0',
              color: const Color(0xFFFF9800),
              isDark: isDark,
              isFullWidth: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PremiumScreen()),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDark,
    bool isFullWidth = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 20,
          horizontal: isFullWidth ? 20 : 16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: isFullWidth
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).hintColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Iconsax.arrow_right_3,
                    color: Theme.of(context).hintColor.withValues(alpha: 0.5),
                    size: 18,
                  ),
                ],
              )
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).hintColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildQuickActionMenu(LanguageProvider languageProvider, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Iconsax.user_edit,
            title: languageProvider.getString('edit_profile_label'),
            subtitle: languageProvider.getString('complete_your_profile'),
            color: _primaryColor,
            onTap: _navigateToEditScreen,
          ),
          Divider(
            height: 1,
            indent: 64,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          // ⚡ Boost Profile entry
          Consumer<ProfileProvider>(
            builder: (context, pp, _) {
              final isBoosted = pp.userProfile?.isBoosted == true;
              final boostExpiry = pp.userProfile?.boostExpiry;
              return ListTile(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const BoostSheet(),
                  );
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: isBoosted
                        ? const LinearGradient(
                            colors: [Color(0xFFFF4D85), Color(0xFFFF9E00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isBoosted
                        ? null
                        : const Color(0xFFFF9E00).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Iconsax.flash5,
                    color: isBoosted ? Colors.white : const Color(0xFFFF9E00),
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Boost Profile',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: Text(
                  isBoosted && boostExpiry != null
                      ? '⚡ Active until ${boostExpiry.day}/${boostExpiry.month}/${boostExpiry.year}'
                      : 'Get 10x more visibility',
                  style: TextStyle(
                    fontSize: 12,
                    color: isBoosted
                        ? const Color(0xFFFF9E00)
                        : Theme.of(context).hintColor,
                    fontWeight: isBoosted ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: Icon(
                  Iconsax.arrow_right_3,
                  size: 18,
                  color: Theme.of(context).hintColor.withValues(alpha: 0.5),
                ),
              );
            },
          ),
          Divider(
            height: 1,
            indent: 64,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          Consumer<ProfileProvider>(
            builder: (context, pp, _) {
              final isPremium = pp.userProfile?.isPremium == true;
              final planName = pp.userProfile?.premiumType ?? 'Premium';
              return _buildMenuItem(
                icon: Iconsax.crown5,
                title: isPremium
                    ? '$planName Subscription'
                    : languageProvider.getString('get_premium'),
                subtitle: isPremium
                    ? 'Active Plan • Manage or Upgrade'
                    : languageProvider.getString('my_credits'),
                color: const Color(0xFFFFB300),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PremiumScreen(),
                  ),
                ),
              );
            },
          ),
          Divider(
            height: 1,
            indent: 64,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          _buildMenuItem(
            icon: Iconsax.setting_2,
            title: languageProvider.getString('settings'),
            subtitle: null,
            color: const Color(0xFF6C5CE7),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            )
          : null,
      trailing: Icon(
        Iconsax.arrow_right_3,
        size: 18,
        color: Theme.of(context).hintColor.withValues(alpha: 0.5),
      ),
    );
  }
}
