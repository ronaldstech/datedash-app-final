import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../widgets/bordered_search_bar.dart';
import '../models/user_profile_model.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import '../services/profile_service.dart';
import '../services/chat_service.dart';
import '../widgets/profile_detail_sheet.dart';
import 'chat_screen.dart';

class LikesScreen extends StatelessWidget {
  final ProfileService _profileService = ProfileService();

  LikesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final languageProvider = context.watch<LanguageProvider>();

    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Text(languageProvider.getString('signin_to_see_likes')),
        ),
      );
    }

    return Scaffold(
      body: StreamBuilder<List<UserProfile>>(
        stream: _profileService.getReceivedLikesStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4D85)),
            );
          }

          final likes = snapshot.data ?? [];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(
                  languageProvider.getString('nav_likes'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                elevation: 0,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                centerTitle: false,
                floating: true,
                snap: true,
                actions: const [BorderedSearchBar(), SizedBox(width: 8)],
              ),
              if (likes.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildNewLikesSection(
                    context,
                    likes,
                    languageProvider,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Text(
                      languageProvider.getString('all_likes'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                _buildLikesGrid(context, likes, languageProvider),
              ] else
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Iconsax.heart_slash,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).iconTheme.color?.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          languageProvider.getString('no_likes_yet'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          languageProvider.getString('keep_swiping_matches'),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNewLikesSection(
    BuildContext context,
    List<UserProfile> likes,
    LanguageProvider lp,
  ) {
    final newLikes = likes.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            '${lp.getString('new_likes')} (${likes.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF4D85),
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: newLikes.length,
            itemBuilder: (context, index) {
              final profile = likes[index];
              final photo = profile.photos.isNotEmpty
                  ? profile.photos.first
                  : 'https://images.unsplash.com/photo-1511367461989-f85a21fda167?q=80&w=800';

              final profileProvider = context.watch<ProfileProvider>();
              final isUnlocked =
                  (profileProvider.userProfile?.isPremium == true &&
                      profileProvider.userProfile?.premiumType?.toUpperCase() ==
                          'ELITE') ||
                  (profileProvider.userProfile?.unlockedLikes.contains(
                        profile.uid,
                      ) ??
                      false);

              return GestureDetector(
                onTap: isUnlocked
                    ? () => _showProfileDetails(context, profile, lp)
                    : () => _showUnlockDialog(context, profile, lp),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isUnlocked
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFFF4D85),
                                    Color(0xFFFF9A8B),
                                  ],
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.grey.withValues(alpha: 0.5),
                                    Colors.grey.withValues(alpha: 0.2),
                                  ],
                                ),
                        ),
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
                          child: ClipOval(
                            child: ImageFiltered(
                              imageFilter: isUnlocked
                                  ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                                  : ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundImage: NetworkImage(photo),
                                onBackgroundImageError: (e, s) {
                                  debugPrint(
                                    'Error loading likes drawer profile: $e',
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLikesGrid(
    BuildContext context,
    List<UserProfile> likes,
    LanguageProvider lp,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final profile = likes[index];
          final photo = profile.photos.isNotEmpty
              ? profile.photos.first
              : 'https://images.unsplash.com/photo-1511367461989-f85a21fda167?q=80&w=800';

          final profileProvider = context.watch<ProfileProvider>();
          final isUnlocked =
              (profileProvider.userProfile?.isPremium == true &&
                  profileProvider.userProfile?.premiumType?.toUpperCase() ==
                      'ELITE') ||
              (profileProvider.userProfile?.unlockedLikes.contains(
                    profile.uid,
                  ) ??
                  false);

          return GestureDetector(
            onTap: isUnlocked
                ? () => _showProfileDetails(context, profile, lp)
                : () => _showUnlockDialog(context, profile, lp),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImageFiltered(
                    imageFilter: isUnlocked
                        ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                        : ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.withValues(alpha: 0.2),
                          child: const Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                  if (!isUnlocked)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Iconsax.lock,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isUnlocked
                                    ? (profile.showAge
                                          ? '${profile.firstName ?? lp.getString('someone_fallback')}, ${profile.age ?? '??'}'
                                          : profile.firstName ??
                                                lp.getString(
                                                  'someone_fallback',
                                                ))
                                    : (profile.showAge
                                          ? '•••••, ${profile.age ?? '??'}'
                                          : '•••••'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (profile.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF4FC3F7),
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (!isUnlocked && profile.lookingFor.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                const Icon(
                                  Iconsax.search_normal_1,
                                  color: Colors.white70,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    profile.lookingFor.first,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isUnlocked)
                          Row(
                            children: [
                              const Icon(
                                Iconsax.location,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                profile.getDistanceDisplay(
                                  profileProvider.userProfile,
                                ),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
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
          );
        }, childCount: likes.length),
      ),
    );
  }

  void _showUnlockDialog(
    BuildContext context,
    UserProfile profile,
    LanguageProvider lp,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final profileProvider = context.watch<ProfileProvider>();
        final photo = profile.photos.isNotEmpty
            ? profile.photos.first
            : 'https://images.unsplash.com/photo-1511367461989-f85a21fda167?q=80&w=800';

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // --- Premium Header ---
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF4D85).withValues(alpha: 0.3),
                        width: 4,
                      ),
                    ),
                    child: ClipOval(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Image.network(photo, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF4D85),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.lock,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Text(
                lp.getString('unlock_title'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  lp.getString('unlock_message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).hintColor,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --- Spark Indicator ---
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Iconsax.coin,
                      color: Color(0xFFFFB300),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your Balance: ${profileProvider.userProfile?.credits ?? 0} Sparks',
                      style: const TextStyle(
                        color: Color(0xFFFFB300),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- Action Buttons ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Unlock with Sparks
                    GestureDetector(
                      onTap: () async {
                        if ((profileProvider.userProfile?.credits ?? 0) < 20) {
                          Navigator.pop(context);
                          profileProvider.navigateToPremium(1);
                          return;
                        }

                        try {
                          Navigator.pop(context);
                          await profileProvider.unlockProfile(profile.uid!);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to unlock: $e')),
                            );
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFFB300,
                              ).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            lp.getString('unlock_for_credits'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Go Premium (Best Value)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        profileProvider.navigateToPremium(0);
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4D85), Color(0xFFFF7DA0)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF4D85,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                lp.getString('go_premium'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'BEST VALUE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  lp.getString('cancel'),
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: 32 + MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  void _showProfileDetails(
    BuildContext context,
    UserProfile profile,
    LanguageProvider lp,
  ) {
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
            await _profileService.swipeUser(
              myUid,
              profile.uid!,
              'like',
              senderName: profileProvider.displayName,
            );
          }
          if (context.mounted) Navigator.pop(context);
        },
        onDislike: () async {
          final profileProvider = context.read<ProfileProvider>();
          final myUid = profileProvider.currentUser?.uid;
          if (myUid != null && profile.uid != null) {
            await _profileService.swipeUser(
              myUid,
              profile.uid!,
              'dislike',
              senderName: profileProvider.displayName,
            );
          }
          if (context.mounted) Navigator.pop(context);
        },
        onMessage: () async {
          final myUid = FirebaseAuth.instance.currentUser?.uid;
          if (myUid == null || profile.uid == null) return;

          try {
            await ChatService().getOrCreateChat(myUid, profile.uid!);

            if (context.mounted) {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    otherUserId: profile.uid!,
                    otherUserName:
                        profile.firstName ?? lp.getString('user_fallback'),
                    otherUserPhoto: profile.photos.isNotEmpty
                        ? profile.photos.first
                        : null,
                  ),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error opening chat: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not open chat: $e')),
              );
            }
          }
        },
      ),
    );
  }
}
