import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/likes_screen.dart';
import '../screens/profile_viewers_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/gifts_screen.dart';
import '../screens/rewards_screen.dart';
import '../theme/theme_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import '../screens/transactions_screen.dart';
import '../screens/live_list_screen.dart';
import '../screens/meetups_screen.dart';
import '../services/meetup_service.dart';
import '../models/meetup_model.dart';
import '../widgets/boost_sheet.dart';

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key});

  void _handleLogout(BuildContext context) async {
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageProvider = context.watch<LanguageProvider>();
    final myUid = context.watch<ProfileProvider>().currentUser?.uid;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Premium Header with Glassmorphism
            Consumer<ProfileProvider>(
              builder: (context, profileProvider, _) {
                final photoUrl = profileProvider.photoURL;
                final displayName = profileProvider.displayName;
                final email =
                    profileProvider.currentUser?.email ??
                    languageProvider.getString('join_community');

                return Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFF4D85).withValues(alpha: 0.15),
                        const Color(0xFFFF4D85).withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFF4D85),
                                    Color(0xFFFF8E8E),
                                  ],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: isDark
                                    ? Colors.black
                                    : Colors.white,
                                child: ClipOval(
                                  child: photoUrl != null
                                      ? Image.network(
                                          photoUrl,
                                          width: 84,
                                          height: 84,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(
                                          Iconsax.user,
                                          size: 40,
                                          color: Color(0xFFFF4D85),
                                        ),
                                ),
                              ),
                            ),
                            if (profileProvider.userProfile?.isVerified == true)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF4D85),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (profileProvider.userProfile?.isVerified ==
                              true) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              color: Color(0xFFFF4D85),
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDrawerTile(
                              context,
                              title: 'Sparks',
                              value: (profileProvider.userProfile?.credits ?? 0)
                                  .toString()
                                  .replaceAllMapped(
                                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                    (Match m) => '${m[1]},',
                                  ),
                              icon: Iconsax.wallet_3,
                              iconColor: const Color(0xFFFFB300),
                              onTap: () {
                                Navigator.pop(context);
                                profileProvider.navigateToPremium(1);
                              },
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDrawerTile(
                              context,
                              title: 'Membership',
                              value:
                                  profileProvider.userProfile?.isPremium == true
                                  ? (profileProvider.userProfile?.premiumType ?? 'Premium')
                                  : 'Free',
                              icon:
                                  profileProvider.userProfile?.isPremium == true
                                  ? Iconsax.crown5
                                  : Iconsax.star5,
                              iconColor: const Color(0xFFFF4D85),
                              onTap: () {
                                Navigator.pop(context);
                                profileProvider.navigateToPremium(0);
                              },
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  const SizedBox(height: 4),

                  // Account Section
                  _buildSectionHeader(
                    context,
                    languageProvider.getString('account_section'),
                  ),
                  _buildItem(
                    context,
                    Iconsax.user,
                    languageProvider.getString('my_profile'),
                    backgroundColor: const Color(0xFFFF4D85),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  _buildItem(
                    context,
                    Iconsax.video_circle,
                    languageProvider.getString('live_videos'),
                    borderColor: const Color(0xFFFF4D85),
                    color: const Color(0xFFFF4D85),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LiveListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildItem(
                    context,
                    Iconsax.setting_2,
                    languageProvider.getString('settings_label'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),

                  // Discovery Section
                  _buildSectionHeader(
                    context,
                    languageProvider.getString('discovery_section'),
                  ),
                  _buildItem(
                    context,
                    Iconsax.discover_1,
                    languageProvider.getString('explore_people'),
                  ),
                  const SizedBox(height: 4),

                  // Activity Section
                  _buildSectionHeader(
                    context,
                    languageProvider.getString('activity_section'),
                  ),
                  _buildItem(
                    context,
                    Iconsax.heart_tick,
                    languageProvider.getString('matches_label'),
                    color: const Color(0xFFFF4D85),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChatListScreen(),
                        ),
                      );
                    },
                  ),
                  myUid == null
                      ? _buildItem(
                          context,
                          Iconsax.calendar_tick,
                          languageProvider.getString('my_meetups'),
                          color: const Color(0xFFFFA000),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MeetupsScreen(),
                              ),
                            );
                          },
                        )
                      : StreamBuilder<List<MeetupModel>>(
                          stream: MeetupService()
                              .getPendingReceivedMeetupsStream(myUid),
                          builder: (context, snapshot) {
                            final pendingCount = snapshot.data?.length ?? 0;
                            Widget? trailingWidget;
                            if (pendingCount > 0) {
                              trailingWidget = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF4D85),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$pendingCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: Theme.of(
                                      context,
                                    ).hintColor.withValues(alpha: 0.5),
                                  ),
                                ],
                              );
                            }
                            return _buildItem(
                              context,
                              Iconsax.calendar_tick,
                              languageProvider.getString('my_meetups'),
                              color: const Color(0xFFFFA000),
                              trailing: trailingWidget,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MeetupsScreen(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                  _buildItem(
                    context,
                    Iconsax.eye,
                    languageProvider.getString('visitors_label'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileViewersScreen(),
                        ),
                      );
                    },
                  ),
                  _buildItem(
                    context,
                    Iconsax.document_text,
                    languageProvider.getString('blog'),
                  ),

                  _buildItem(
                    context,
                    Iconsax.heart5,
                    languageProvider.getString('likes_label'),
                    color: const Color(0xFFFF4D85),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LikesScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildItem(
                    context,
                    Iconsax.cup,
                    'Rewards',
                    color: Colors.orangeAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RewardsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildItem(
                    context,
                    Iconsax.gift,
                    languageProvider.getString('gifts'),
                    color: Colors.purple.shade300,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GiftsScreen()),
                      );
                    },
                  ),
                  _buildItem(
                    context,
                    Iconsax.flash5,
                    'Boost Profile',
                    color: const Color(0xFFFF9E00),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const BoostSheet(),
                      );
                    },
                  ),
                  _buildItem(
                    context,
                    Iconsax.receipt_21,
                    languageProvider.getString('transactions'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TransactionsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Appearance Section
                  _buildSectionHeader(
                    context,
                    languageProvider.getString('appearance_section'),
                  ),
                  _buildThemeToggle(context, languageProvider),
                  const SizedBox(height: 20),

                  // Support Section
                  _buildSectionHeader(
                    context,
                    languageProvider.getString('support_section'),
                  ),
                  _buildItem(
                    context,
                    Iconsax.info_circle,
                    languageProvider.getString('about_us'),
                  ),
                  _buildItem(
                    context,
                    Iconsax.security_safe,
                    languageProvider.getString('safety_tips'),
                  ),
                  const SizedBox(height: 32),
                  _buildLogoutButton(context, languageProvider),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : Colors.black54,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: Theme.of(context).hintColor.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    IconData icon,
    String title, {
    Color? color,
    Color? backgroundColor,
    Color? borderColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              borderColor ??
              (backgroundColor != null
                  ? backgroundColor.withValues(alpha: 0.3)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05))),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: backgroundColor != null
                  ? Colors.white.withValues(alpha: 0.2)
                  : (color ?? const Color(0xFFFF4D85)).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: backgroundColor != null
                  ? Colors.white
                  : (color ?? Theme.of(context).iconTheme.color),
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: backgroundColor != null ? Colors.white : null,
            ),
          ),
          trailing:
              trailing ??
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: backgroundColor != null
                    ? Colors.white.withValues(alpha: 0.7)
                    : Theme.of(context).hintColor.withValues(alpha: 0.5),
              ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildThemeToggle(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isDark ? Iconsax.moon : Iconsax.sun_1, size: 22),
              const SizedBox(width: 12),
              Text(
                isDark
                    ? languageProvider.getString('dark_mode')
                    : languageProvider.getString('light_mode'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Switch.adaptive(
            value: isDark,
            activeThumbColor: const Color(0xFFFF4D85),
            onChanged: (_) => themeProvider.toggleTheme(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: ListTile(
        onTap: () => _handleLogout(context),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Iconsax.logout, color: Colors.redAccent, size: 20),
        ),
        title: Text(
          languageProvider.getString('logout'),
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          languageProvider.getString('logout_sub'),
          style: const TextStyle(fontSize: 12),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
        ),
        tileColor: Colors.redAccent.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
