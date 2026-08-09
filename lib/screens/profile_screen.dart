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
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.3),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  _buildProfileHeader(languageProvider, isDark),
                  const SizedBox(height: 28),
                  _buildCompletionCard(languageProvider, isDark),
                  const SizedBox(height: 28),
                  _buildStatsGrid(languageProvider, isDark),
                  const SizedBox(height: 28),
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
                      color: _primaryColor.withValues(alpha: isDark ? 0.35 : 0.2),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: CircleAvatar(
                  radius: 64,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: _primaryColor.withValues(alpha: 0.1),
                    child: ClipOval(
                      child: (_profile.photos.isNotEmpty || _user?.photoURL != null)
                          ? Image.network(
                              _profile.photos.isNotEmpty
                                  ? _profile.photos.first
                                  : _user!.photoURL!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _primaryColor,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Iconsax.user, size: 48, color: _primaryColor);
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
                    )
                  ],
                ),
                child: const Icon(Iconsax.edit_2, color: Colors.white, size: 18),
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
            _user!.email!,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
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
              color: (isComplete ? Colors.green : _primaryColor)
                  .withValues(alpha: isDark ? 0.4 : 0.25),
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
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
              child: const Icon(Iconsax.arrow_right_3, color: Colors.white, size: 20),
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
          _buildMenuItem(
            icon: Iconsax.crown5,
            title: languageProvider.getString('get_premium'),
            subtitle: languageProvider.getString('my_credits'),
            color: const Color(0xFFFFB300),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PremiumScreen()),
            ),
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
