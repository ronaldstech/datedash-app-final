import 'package:snellum/screens/auth/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:ui';
import '../widgets/swipe_view.dart';
import '../widgets/profile_drawer.dart';
import 'explore_screen.dart';
import 'likes_screen.dart';
import 'chat_list_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/profile_provider.dart';
import '../services/notification_service.dart';
import 'notification_screen.dart';
import 'swipe_filters_screen.dart';
import 'premium_screen.dart';
import 'live_list_screen.dart';
import '../providers/language_provider.dart';
import '../widgets/mandatory_phone_sheet.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_lock_screen.dart';
import '../widgets/incomplete_profile_wizard.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  static bool ignoreNextLock = false;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with WidgetsBindingObserver {
  bool _isPhoneSheetShowing = false;
  bool _isUnlocked = false;
  bool _isLockChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAppLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (LandingScreen.ignoreNextLock) {
        LandingScreen.ignoreNextLock = false;
        return;
      }
      // Switched to other app or backgrounded -> IMMEDIATELY lock the app
      _lockAppImmediately();
    }
  }

  Future<void> _lockAppImmediately() async {
    final prefs = await SharedPreferences.getInstance();
    final isLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
    final savedPin = prefs.getString('app_lock_pin');

    if (isLockEnabled && savedPin != null) {
      setState(() {
        _isUnlocked = false;
      });
    }
  }

  Future<void> _checkAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    final isLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
    final savedPin = prefs.getString('app_lock_pin');

    if (isLockEnabled && savedPin != null) {
      setState(() {
        _isUnlocked = false;
        _isLockChecking = false;
      });
    } else {
      setState(() {
        _isUnlocked = true;
        _isLockChecking = false;
      });
    }
  }

  void _showMandatoryPhoneSheet(BuildContext context) {
    if (_isPhoneSheetShowing) return;
    _isPhoneSheetShowing = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MandatoryPhoneSheet(),
    ).then((_) {
      _isPhoneSheetShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLockChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F12),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF4D85)),
        ),
      );
    }

    if (!_isUnlocked) {
      return AppLockScreen(
        onUnlock: () {
          setState(() {
            _isUnlocked = true;
          });
        },
      );
    }

    final languageProvider = context.watch<LanguageProvider>();
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        if (profileProvider.userProfile == null) {
          if (FirebaseAuth.instance.currentUser == null) {
            return const SignInScreen();
          }
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4D85)),
            ),
          );
        }

        // Check if phone number is missing
        final isPhoneMissing =
            profileProvider.userProfile!.phoneNumber == null ||
            profileProvider.userProfile!.phoneNumber!.isEmpty;

        if (isPhoneMissing) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _showMandatoryPhoneSheet(context);
          });
        }

        final completion = profileProvider.userProfile!.completionPercentage;
        final isProfileIncomplete = completion < 40;

        final currentIndex = profileProvider.currentTabIndex;
        final selectedCategory = profileProvider.selectedExploreCategory;

        return Stack(
          children: [
            Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              extendBody: true,
              appBar: AppBar(
                leading: (currentIndex == 1 && selectedCategory != null)
                    ? IconButton(
                        icon: const Icon(Iconsax.arrow_left_2),
                        onPressed: () {
                          profileProvider.setExploreCategory(null);
                        },
                      )
                    : null,
                title: Text(
                  (currentIndex == 1 && selectedCategory != null)
                      ? _getLocalizedCategoryName(
                          selectedCategory,
                          languageProvider,
                        )
                      : 'Snellum',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: (currentIndex == 1 && selectedCategory != null)
                        ? 20
                        : 26,
                    color: const Color(0xFFFF4D85),
                    letterSpacing: -0.5,
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  if (currentIndex == 0 ||
                      (currentIndex == 1 &&
                          selectedCategory !=
                              null)) // Show Filter icon on Swipe View OR Category Swipe
                    IconButton(
                      icon: Icon(
                        Iconsax.setting_4,
                        color: Theme.of(
                          context,
                        ).iconTheme.color?.withValues(alpha: 0.7),
                        size: 22,
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const SwipeFiltersScreen(),
                        );
                      },
                    ),
                  StreamBuilder<int>(
                    stream: NotificationService().getUnreadCountStream(
                      FirebaseAuth.instance.currentUser?.uid ?? '',
                    ),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      return Stack(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationScreen(),
                                ),
                              );
                            },
                            icon: Icon(
                              Iconsax.notification,
                              color: Theme.of(
                                context,
                              ).iconTheme.color?.withValues(alpha: 0.7),
                              size: 20,
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF4D85),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 14,
                                  minHeight: 14,
                                ),
                                child: Text(
                                  unreadCount > 9
                                      ? '9+'
                                      : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  Consumer<ProfileProvider>(
                    builder: (context, profileProvider, _) {
                      final photoUrl = profileProvider.photoURL;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: IconButton(
                          onPressed: () => Scaffold.of(context).openEndDrawer(),
                          icon: photoUrl != null
                              ? CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: NetworkImage(photoUrl),
                                )
                              : Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Iconsax.user,
                                    color: Theme.of(
                                      context,
                                    ).iconTheme.color?.withValues(alpha: 0.7),
                                    size: 20,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              body: IndexedStack(
                index: currentIndex,
                children: [
                  const SwipeView(),
                  const ExploreScreen(),
                  LikesScreen(),
                  const ChatListScreen(),
                  const LiveListScreen(),
                  PremiumScreen(initialTab: profileProvider.initialPremiumTab),
                ],
              ),
              endDrawer: const ProfileDrawer(),
              bottomNavigationBar: Container(
                margin: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          0,
                          Iconsax.flash,
                          Iconsax.flash5,
                          languageProvider.getString('nav_swipe'),
                          currentIndex,
                          profileProvider,
                        ),
                        _buildNavItem(
                          1,
                          Iconsax.discover,
                          Iconsax.discover5,
                          languageProvider.getString('nav_explore'),
                          currentIndex,
                          profileProvider,
                        ),
                        _buildNavItem(
                          2,
                          Iconsax.heart,
                          Iconsax.heart5,
                          languageProvider.getString('nav_likes'),
                          currentIndex,
                          profileProvider,
                          hasBadge: true,
                        ),
                        _buildNavItem(
                          3,
                          Iconsax.message,
                          Iconsax.message5,
                          languageProvider.getString('nav_chat'),
                          currentIndex,
                          profileProvider,
                          hasBadge: true,
                        ),
                        _buildNavItem(
                          4,
                          Iconsax.video,
                          Iconsax.video5,
                          languageProvider.getString('nav_video'),
                          currentIndex,
                          profileProvider,
                        ),
                        _buildNavItem(
                          5,
                          Iconsax.crown,
                          Iconsax.crown5,
                          'Premium',
                          currentIndex,
                          profileProvider,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Stunning Full-Screen Swipe Border Overlay
            if (profileProvider.swipeOffset != 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Builder(
                    builder: (context) {
                      final offset = profileProvider.swipeOffset;
                      final isLike = offset > 0;
                      final progress = (offset.abs() / 150).clamp(0.0, 1.0);

                      // Like: green → teal → cyan palette
                      // Dislike: red → coral → orange palette
                      final borderColor = isLike
                          ? Color.lerp(
                              const Color(0xFF00E676),
                              const Color(0xFF00BCD4),
                              progress * 0.6,
                            )!
                          : Color.lerp(
                              const Color(0xFFFF1744),
                              const Color(0xFFFF6D00),
                              progress * 0.6,
                            )!;

                      final glowInner = isLike
                          ? const Color(0xFF00E676)
                          : const Color(0xFFFF1744);
                      final glowMid = isLike
                          ? const Color(0xFF69F0AE)
                          : const Color(0xFFFF6E40);
                      final glowOuter = isLike
                          ? const Color(0xFF00BCD4)
                          : const Color(0xFFFF9100);

                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: borderColor.withValues(
                              alpha: progress.clamp(0.3, 1.0),
                            ),
                            width: 5 + (progress * 3), // Grows from 5→8px
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                          boxShadow: [
                            // Tight inner glow
                            BoxShadow(
                              color: glowInner.withValues(
                                alpha: (progress * 0.9).clamp(0, 0.9),
                              ),
                              blurRadius: 16,
                              spreadRadius: 2,
                              blurStyle: BlurStyle.outer,
                            ),
                            // Mid halo
                            BoxShadow(
                              color: glowMid.withValues(
                                alpha: (progress * 0.6).clamp(0, 0.6),
                              ),
                              blurRadius: 40,
                              spreadRadius: 8,
                              blurStyle: BlurStyle.outer,
                            ),
                            // Wide diffuse outer glow
                            BoxShadow(
                              color: glowOuter.withValues(
                                alpha: (progress * 0.35).clamp(0, 0.35),
                              ),
                              blurRadius: 80,
                              spreadRadius: 20,
                              blurStyle: BlurStyle.outer,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Incomplete Profile Block Overlay
            if (isProfileIncomplete)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.9),
                    child: IncompleteProfileWizard(
                      profile: profileProvider.userProfile!,
                      completion: completion,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
    int currentIndex,
    ProfileProvider profileProvider, {
    bool hasBadge = false,
  }) {
    final isSelected = currentIndex == index;
    final color = isSelected
        ? const Color(0xFFFF4D85)
        : Theme.of(context).hintColor.withValues(alpha: 0.6);

    int badgeCount = 0;
    if (hasBadge) {
      badgeCount = index == 2
          ? profileProvider.newLikesCount
          : profileProvider.unreadMessageCount;
    }

    return GestureDetector(
      onTap: () => profileProvider.setTabIndex(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: hasBadge && badgeCount > 0,
              backgroundColor: const Color(0xFFFF4D85),
              label: Text(
                badgeCount.toString(),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLocalizedCategoryName(String key, LanguageProvider lp) {
    switch (key) {
      case 'Marriage':
        return lp.getString('cat_marriage');
      case 'Long Term Relationship':
        return lp.getString('cat_long_term');
      case 'Short Term Relationship':
        return lp.getString('cat_short_term_rel');
      case 'Hookups':
        return lp.getString('cat_hookups');
      case 'Short Term Fun':
        return lp.getString('cat_short_term');
      case 'New Friends':
        return lp.getString('cat_new_friends');
      case 'Coffee Date':
        return lp.getString('cat_coffee_date');
      case 'Learn Cultures':
        return lp.getString('cat_movie_night');
      case 'Sponsor':
        return lp.getString('cat_sponsor');
      case 'Figuring Out':
        return lp.getString('cat_figuring_out');
      default:
        return key;
    }
  }
}
