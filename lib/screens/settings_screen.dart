import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_db_service.dart';
import 'premium_screen.dart';
import 'verification_screen.dart';
import 'edit_profile_screen.dart';
import 'security_settings_screen.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.getString('settings_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          _buildSectionHeader(languageProvider.getString('account')),
          _buildSettingTile(
            context,
            Iconsax.user_edit,
            languageProvider.getString('edit_profile'),
            languageProvider.getString('edit_profile_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const EditProfileScreen()),
            ),
          ),
          _buildVerificationTile(context, languageProvider, profileProvider),
          _buildSettingTile(
            context,
            Iconsax.lock,
            languageProvider.getString('security'),
            languageProvider.getString('security_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const SecuritySettingsScreen()),
            ),
          ),
          const SizedBox(height: 20),
          _buildPrivacySection(context, languageProvider),
          const SizedBox(height: 20),
          _buildMeetupSection(context, languageProvider),
          const SizedBox(height: 20),
          _buildSectionHeader(languageProvider.getString('preferences')),
          _buildThemeTile(context, themeProvider, languageProvider),
          _buildSettingTile(
            context,
            Iconsax.notification,
            languageProvider.getString('notifications'),
            languageProvider.getString('notifications_sub'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen()),
            ),
          ),
          _buildLanguageTile(context),
          const SizedBox(height: 20),
          _buildSectionHeader(languageProvider.getString('discovery')),
          _buildResetSwipesTile(context),
          const SizedBox(height: 20),
          _buildSectionHeader(languageProvider.getString('support')),
          _buildSettingTile(
            context,
            Iconsax.info_circle,
            languageProvider.getString('help_center'),
            languageProvider.getString('help_center_sub'),
          ),
          _buildSettingTile(
            context,
            Iconsax.document_text,
            languageProvider.getString('terms_of_service'),
            languageProvider.getString('terms_of_service_sub'),
          ),
          const SizedBox(height: 30),
          _buildDangerZone(context),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12, top: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFFFF4D85),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 	
                Theme.of(context).brightness == Brightness.light ? 0.03 : 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4D85).withValues(alpha: 	0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFFF4D85), size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Iconsax.arrow_right_3,
          size: 18,
          color: Theme.of(context).hintColor,
        ),
        onTap: onTap ?? () {},
      ),
    );
  }

  Widget _buildResetSwipesTile(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 	0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 	0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 	0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Iconsax.refresh, color: Colors.orange, size: 22),
        ),
        title: Text(
          context.read<LanguageProvider>().getString('reset_swipes'),
          style: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          context.read<LanguageProvider>().getString('reset_swipes_sub'),
          style: const TextStyle(color: Colors.orange, fontSize: 12),
        ),
        trailing:
            const Icon(Iconsax.arrow_right_3, size: 18, color: Colors.orange),
        onTap: () =>
            _showResetSwipesDialog(context, context.read<LanguageProvider>()),
      ),
    );
  }

  void _showResetSwipesDialog(
      BuildContext context, LanguageProvider languageProvider) {
    final profileProvider = context.read<ProfileProvider>();
    final isPremium = profileProvider.userProfile?.isPremium ?? false;

    if (isPremium) {
      // Standard reset dialog for Premium users
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Iconsax.refresh, color: Colors.orange),
              const SizedBox(width: 10),
              Text(languageProvider.getString('reset_swipes_title'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          content: Text(
            languageProvider.getString('reset_swipes_content'),
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(languageProvider.getString('cancel'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await profileProvider.resetSwipes();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                languageProvider
                                    .getString('swipes_reset_success'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            languageProvider.getString('swipes_reset_failed')),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                }
              },
              child: Text(languageProvider.getString('reset'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }

    // Non-premium: Show spark cost dialog
    final sparks = profileProvider.userProfile?.sparks ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Iconsax.refresh, color: Color(0xFFFF4D85)),
            const SizedBox(width: 10),
            Text(languageProvider.getString('refresh_cost_title'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          languageProvider
              .getString('refresh_cost_content')
              .replaceAll('{credits}', sparks.toString()),
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(languageProvider.getString('cancel'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D85),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (sparks < 50) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:
                      Text(languageProvider.getString('not_enough_credits')),
                  backgroundColor: const Color(0xFFFF4D85),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  margin: const EdgeInsets.all(20),
                ));
                return;
              }

              try {
                await profileProvider.useCredits(50);
                await profileProvider.resetSwipes();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              languageProvider
                                  .getString('swipes_reset_success'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          languageProvider.getString('swipes_reset_failed')),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              }
            },
            child: Text(languageProvider.getString('pay_refresh'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTile(BuildContext context, ThemeProvider themeProvider,
      LanguageProvider languageProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 	
                Theme.of(context).brightness == Brightness.light ? 0.03 : 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 	0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            themeProvider.isDarkMode ? Iconsax.moon5 : Iconsax.sun5,
            color: Colors.deepPurple,
            size: 22,
          ),
        ),
        title: Text(
          languageProvider.getString('night_mode'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(
          themeProvider.isDarkMode
              ? languageProvider.getString('night_mode_on')
              : languageProvider.getString('night_mode_off'),
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontSize: 12,
          ),
        ),
        value: themeProvider.isDarkMode,
        activeThumbColor: const Color(0xFFFF4D85),
        onChanged: (_) => themeProvider.toggleTheme(),
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    return Column(
      children: [
        // Wipe Data Tile
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 	0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withValues(alpha: 	0.1)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.refresh, color: Colors.white, size: 20),
            ),
            title: Text(
              languageProvider.getString('wipe_local_data'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: Text(
              languageProvider.getString('wipe_local_data_sub'),
              style:
                  TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
            ),
            onTap: () => _showWipeDataConfirmation(context),
          ),
        ),
        // Delete Account Tile
        Container(
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 	0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withValues(alpha: 	0.1)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.trash, color: Colors.white, size: 20),
            ),
            title: Text(
              languageProvider.getString('delete_account'),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              languageProvider.getString('delete_account_sub'),
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
            onTap: () {
              // Show confirmation dialog
            },
          ),
        ),
      ],
    );
  }

  void _showWipeDataConfirmation(BuildContext context) {
    final languageProvider = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          languageProvider.getString('wipe_confirm_title'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          languageProvider.getString('wipe_confirm_content'),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              languageProvider.getString('cancel'),
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Show loading indicator
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Text(languageProvider.getString('saving_label')),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }

                // 1. Clear Firestore Persistence
                await FirebaseFirestore.instance.terminate();
                await FirebaseFirestore.instance.clearPersistence();

                // 2. Clear Local SQLite DB
                await LocalDbService().clearAllData();

                // 3. Clear SharedPreferences (preserve language)
                final prefs = await SharedPreferences.getInstance();
                final lang = prefs.getString('app_language_code');
                await prefs.clear();
                if (lang != null) {
                  await prefs.setString('app_language_code', lang);
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(languageProvider.getString('wipe_success')),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(languageProvider.getString('wipe_failed')),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              languageProvider.getString('confirm_button'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(
      BuildContext context, LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(languageProvider.getString('privacy_visibility')),
        Consumer<ProfileProvider>(
          builder: (context, profileProvider, _) {
            final profile = profileProvider.userProfile;
            if (profile == null) return const SizedBox.shrink();

            final isPremium = profileProvider.userProfile?.isPremium ?? false;
            final isElite = isPremium && profileProvider.userProfile?.premiumType?.toUpperCase() == 'ELITE';

            return Column(
              children: [
                _buildPrivacyTile(
                  context,
                  Iconsax.user_tag,
                  languageProvider.getString('show_age'),
                  languageProvider.getString('show_age_sub'),
                  profile.showAge,
                  (val) {
                    if (!isElite) {
                      _showPremiumDialog(context, languageProvider, requiredTier: 'ELITE');
                      return;
                    }
                    profile.showAge = val;
                    final user = profileProvider.currentUser;
                    if (user != null) {
                      profileProvider.saveUserProfile(user.uid, profile);
                    }
                  },
                  isPremiumLocked: !isElite,
                ),
                _buildPrivacyTile(
                  context,
                  Iconsax.location_add,
                  languageProvider.getString('show_distance'),
                  languageProvider.getString('show_distance_sub'),
                  profile.showDistance,
                  (val) {
                    if (!isPremium) {
                      _showPremiumDialog(context, languageProvider, requiredTier: 'PREMIUM');
                      return;
                    }
                    profile.showDistance = val;
                    final user = profileProvider.currentUser;
                    if (user != null) {
                      profileProvider.saveUserProfile(user.uid, profile);
                    }
                  },
                  isPremiumLocked: !isPremium,
                ),
                _buildPrivacyTile(
                  context,
                  Iconsax.eye_slash,
                  languageProvider.getString('hide_profile'),
                  languageProvider.getString('hide_profile_sub'),
                  profile.hideProfile,
                  (val) {
                    if (!isElite) {
                      _showPremiumDialog(context, languageProvider, requiredTier: 'ELITE');
                      return;
                    }
                    profile.hideProfile = val;
                    final user = profileProvider.currentUser;
                    if (user != null) {
                      profileProvider.saveUserProfile(user.uid, profile);
                    }
                  },
                  isPremiumLocked: !isElite,
                ),
                _buildPrivacyTile(
                  context,
                  Iconsax.message_notif,
                  languageProvider.getString('allow_messages_label'),
                  languageProvider.getString('allow_messages_sub'),
                  profile.allowMessages,
                  (val) {
                    profile.allowMessages = val;
                    final user = profileProvider.currentUser;
                    if (user != null) {
                      profileProvider.saveUserProfile(user.uid, profile);
                    }
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMeetupSection(
      BuildContext context, LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            languageProvider.getString('booking_section_title')),
        Consumer<ProfileProvider>(
          builder: (context, profileProvider, _) {
            final profile = profileProvider.userProfile;
            if (profile == null) return const SizedBox.shrink();

            return Column(
              children: [
                _buildPrivacyTile(
                  context,
                  Iconsax.calendar_tick,
                  languageProvider.getString('allow_bookings_label'),
                  languageProvider.getString('allow_bookings_sub'),
                  profile.allowMeetupRequests,
                  (val) {
                    profile.allowMeetupRequests = val;
                    final user = profileProvider.currentUser;
                    if (user != null) {
                      profileProvider.saveUserProfile(user.uid, profile);
                    }
                  },
                ),
                _buildSettingTile(
                  context,
                  Iconsax.calendar_edit,
                  languageProvider.getString('booking_details'),
                  languageProvider.getString('booking_details_sub'),
                  onTap: () => _showMeetupPreferencesSheet(context),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildVerificationTile(BuildContext context,
      LanguageProvider languageProvider, ProfileProvider profileProvider) {
    final profile = profileProvider.userProfile;
    final status = profile?.verificationStatus ?? 'unverified';

    IconData iconData = Iconsax.verify;
    Color iconColor = const Color(0xFFFF4D85);

    if (status == 'verified') {
      iconColor = Colors.green;
    } else if (status == 'pending') {
      iconColor = Colors.orange;
    } else if (status == 'failed' || status == 'canceled') {
      iconColor = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 	
                Theme.of(context).brightness == Brightness.light ? 0.03 : 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 	0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(iconData, color: iconColor, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                languageProvider.getString('verification_status_$status'),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            if (status == 'verified') ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified, color: Colors.green, size: 16),
            ] else if (status == 'pending') ...[
              const SizedBox(width: 6),
              const Icon(Icons.hourglass_empty_rounded,
                  color: Colors.orange, size: 16),
            ],
          ],
        ),
        subtitle: Text(
          languageProvider.getString('verification_status_${status}_sub'),
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Iconsax.arrow_right_3,
          size: 18,
          color: Theme.of(context).hintColor,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VerificationScreen()),
          );
        },
      ),
    );
  }

  void _showMeetupPreferencesSheet(BuildContext context) {
    final languageProvider = context.read<LanguageProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final profile = profileProvider.userProfile;

    if (profile == null) return;

    final locationCtrl = TextEditingController(text: profile.meetupLocation);
    final rateCtrl = TextEditingController(text: profile.meetupRate);
    final notesCtrl = TextEditingController(text: profile.meetupNotes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              20,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 	0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Iconsax.calendar_edit,
                      color: Color(0xFFFFA000), size: 28),
                  const SizedBox(width: 12),
                  Text(
                    languageProvider.getString('booking_details'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                languageProvider.getString('booking_details_hint'),
                style:
                    TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: locationCtrl,
                decoration: InputDecoration(
                  labelText:
                      languageProvider.getString('booking_location_label'),
                  hintText: 'e.g., Downtown, Starbucks, Central Park',
                  prefixIcon: const Icon(Iconsax.location),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: rateCtrl,
                decoration: InputDecoration(
                  labelText: languageProvider.getString('booking_rate_label'),
                  hintText: 'e.g., \$50/hr, Drinks on you, Free',
                  prefixIcon: const Icon(Iconsax.money),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: languageProvider.getString('booking_notes_label'),
                  hintText:
                      'Any specific rules, preferences, or notes for your dates...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 32.0),
                    child: Icon(Iconsax.note_text),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    profile.meetupLocation = locationCtrl.text.trim();
                    profile.meetupRate = rateCtrl.text.trim();
                    profile.meetupNotes = notesCtrl.text.trim();

                    final user = profileProvider.currentUser;
                    if (user != null) {
                      profileProvider.saveUserProfile(user.uid, profile);
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text(languageProvider.getString('saving_label'))),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA000),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    languageProvider.getString('save'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPremiumDialog(
      BuildContext context, LanguageProvider languageProvider, {String requiredTier = 'Premium'}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Iconsax.crown5, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Text(
              languageProvider.currentLanguageCode == 'sw'
                  ? 'Kipengele cha $requiredTier'
                  : '$requiredTier Feature',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Text(
          languageProvider.currentLanguageCode == 'sw'
              ? 'Hiki ni kipengele cha $requiredTier. Boresha mpango wako ili kupata udhibiti kamili!'
              : 'This is a $requiredTier feature. Upgrade your plan to gain full control!',
          style: const TextStyle(height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              languageProvider.getString('cancel'),
              style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
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
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              languageProvider.currentLanguageCode == 'sw'
                  ? 'Pata Premium'
                  : 'Upgrade Now',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged, {
    bool isPremiumLocked = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 	
                Theme.of(context).brightness == Brightness.light ? 0.03 : 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4D85).withValues(alpha: 	0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFF4D85),
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            if (isPremiumLocked) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 	0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 	0.3), width: 0.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.crown, color: Colors.amber, size: 10),
                    SizedBox(width: 2),
                    Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontSize: 12,
          ),
        ),
        value: value,
        activeThumbColor: const Color(0xFFFF4D85),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    return _buildSettingTile(
      context,
      Iconsax.global,
      languageProvider.getString('language'),
      languageProvider.currentLanguageName,
      onTap: () => _showLanguageSelector(context),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    final languageProvider = context.read<LanguageProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageProvider.getString('select_language'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: languageProvider.supportedLanguages.map((lang) {
                    final isSelected =
                        languageProvider.currentLanguageCode == lang['code'];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF4D85).withValues(alpha: 	0.1)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Iconsax.global,
                          size: 18,
                          color: isSelected
                              ? const Color(0xFFFF4D85)
                              : Theme.of(context).hintColor,
                        ),
                      ),
                      title: Text(
                        lang['name']!,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFFFF4D85) : null,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                              color: Color(0xFFFF4D85))
                          : null,
                      onTap: () {
                        languageProvider.setLanguage(lang['code']!);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
