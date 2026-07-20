import 'package:datedash/providers/profile_provider.dart';
import 'package:datedash/screens/premium_screen.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.getString('my_profile'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.setting_2),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : RefreshIndicator(
              color: _primaryColor,
              onRefresh: _loadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                children: [
                  _buildProfileHeader(languageProvider),
                  const SizedBox(height: 36),
                  _buildCompletionCard(languageProvider),
                  const SizedBox(height: 32),
                  _buildStatsGrid(languageProvider),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(LanguageProvider languageProvider) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 	0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: CircleAvatar(
                radius: 65,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                child: CircleAvatar(
                  radius: 61,
                  backgroundColor: _primaryColor.withValues(alpha: 	0.1),
                  child: ClipOval(
                    child: (_profile.photos.isNotEmpty ||
                            _user?.photoURL != null)
                        ? Image.network(
                            _profile.photos.isNotEmpty
                                ? _profile.photos.first
                                : _user!.photoURL!,
                            width: 122,
                            height: 122,
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
                              return Icon(Iconsax.user,
                                  size: 50, color: _primaryColor);
                            },
                          )
                        : Icon(Iconsax.user, size: 50, color: _primaryColor),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor, width: 3),
              ),
              child: const Icon(Iconsax.edit_2, color: Colors.white, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          _profile.firstName ??
              _user?.displayName ??
              languageProvider.getString('welcome_back'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          _user?.email ?? '',
          style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildCompletionCard(LanguageProvider languageProvider) {
    final bool isComplete = _profile.completionPercentage == 100;

    return GestureDetector(
      onTap: _navigateToEditScreen,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isComplete
                ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                : [_primaryColor, const Color(0xFFFF7A9F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color:
                  (isComplete ? Colors.green : _primaryColor).withValues(alpha: 	0.3),
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
                  width: 65,
                  height: 65,
                  child: CircularProgressIndicator(
                    value: _profile.completionPercentage / 100,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withValues(alpha: 	0.3),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Text(
                  '${_profile.completionPercentage}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
            const SizedBox(width: 20),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isComplete
                        ? languageProvider.getString('tap_update_details')
                        : languageProvider.getString('matches_3x_likely'),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 	0.9),
                        fontSize: 14,
                        height: 1.3),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 	0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.arrow_right_3,
                  color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(LanguageProvider languageProvider) {
    if (_user == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            // Likes Stat
            Expanded(
              child: StreamBuilder<int>(
                stream: _profileService.getLikesCountStream(_user.uid),
                builder: (context, snapshot) {
                  return _buildStatCard(
                    Iconsax.heart5,
                    languageProvider.getString('likes_label'),
                    snapshot.data?.toString() ?? '0',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LikesScreen()),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            // Views Stat
            Expanded(
              child: StreamBuilder<int>(
                stream: _profileService.getViewCountStream(_user.uid),
                builder: (context, snapshot) {
                  return _buildStatCard(
                    Iconsax.eye,
                    languageProvider.getString('views_label'),
                    snapshot.data?.toString() ?? '0',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ProfileViewersScreen()),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Credits Stat (Full Width)
        Consumer<ProfileProvider>(
          builder: (context, profileProvider, _) {
            return _buildStatCard(
              Iconsax.wallet_3,
              languageProvider.getString('my_credits'),
              profileProvider.userProfile?.credits.toString() ?? '0',
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

  Widget _buildStatCard(IconData icon, String title, String value,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black.withValues(alpha: 	0.04)
                  : Colors.black.withValues(alpha: 	0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 	0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _primaryColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).hintColor,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

