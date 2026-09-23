import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile_model.dart';
import '../../providers/language_provider.dart';
import '../../providers/profile_provider.dart';
import '../action_button.dart';
import '../gift_selection_sheet.dart';
import 'swipe_photo_nav.dart';

/// Represents a single profile card in the swipe deck.
///
/// Owns the photo display, gradients, photo indicators, distributed detail
/// chips, the action row, and the premium photo-navigation buttons.
class SwipeProfileCard extends StatelessWidget {
  const SwipeProfileCard({
    super.key,
    required this.profile,
    required this.photoUrl,
    required this.totalPhotos,
    required this.photoIndex,
    required this.languageProvider,
    this.isBackCard = false,
    this.hasMinPhotos = true,
    this.onNextPhoto,
    this.onPrevPhoto,
    this.onInfoTap,
    this.canRewind = false,
    this.onRewind,
    this.onPass,
    this.onLike,
    this.showMeet = false,
    this.canMeet = true,
    this.onMeet,
    this.showMessageButton = false,
    this.canMessage = true,
    this.onMessage,
  });

  final UserProfile profile;
  final String photoUrl;
  final int totalPhotos;
  final int photoIndex;
  final LanguageProvider languageProvider;
  final bool isBackCard;
  final bool hasMinPhotos;
  final VoidCallback? onNextPhoto;
  final VoidCallback? onPrevPhoto;
  final VoidCallback? onInfoTap;
  final bool canRewind;
  final VoidCallback? onRewind;
  final VoidCallback? onPass;
  final VoidCallback? onLike;
  final bool showMeet;
  final bool canMeet;
  final VoidCallback? onMeet;
  final bool showMessageButton;
  final bool canMessage;
  final VoidCallback? onMessage;

  bool get _showNav => !isBackCard && totalPhotos > 1;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The actual card body with clipping
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 32,
                  offset: const Offset(0, 16)),
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Dark background â€“ always visible, prevents back card bleed-through during photo loads
                const ColoredBox(color: Color(0xFF1A1A2E)),

                // Profile photo with crossfade transition between photos
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Image.network(
                    photoUrl,
                    key: ValueKey(photoUrl),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(color: Color(0xFF1A1A2E)),
                    loadingBuilder: (_, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const ColoredBox(color: Color(0xFF1A1A2E));
                    },
                  ),
                ),

                // Top gradient (dark fade for indicators)
                IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xCC000000), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        stops: [0.0, 1.0],
                      ),
                    ),
                  ),
                ),

                // Bottom gradient (rich and deep)
                IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xDD000000),
                          Color(0xF5000000)
                        ],
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.65, 1.0],
                      ),
                    ),
                  ),
                ),

                // Photo tap areas (only front card)
                if (!isBackCard && onNextPhoto != null && onPrevPhoto != null)
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(
                            child: GestureDetector(
                                key: const ValueKey('prev_photo'),
                                onTap: onPrevPhoto,
                                behavior: HitTestBehavior.opaque,
                                child: const SizedBox.expand())),
                        Expanded(
                            child: GestureDetector(
                                key: const ValueKey('next_photo'),
                                onTap: onNextPhoto,
                                behavior: HitTestBehavior.opaque,
                                child: const SizedBox.expand())),
                      ],
                    ),
                  ),

                // Photo indicators
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: IgnorePointer(
                    child: Row(
                      children: List.generate(
                          totalPhotos,
                          (index) => Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: index == photoIndex ? 4 : 3,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: index == photoIndex
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: index == photoIndex
                                        ? [
                                            BoxShadow(
                                                color: Colors.white
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 6)
                                          ]
                                        : [],
                                  ),
                                ),
                              )),
                    ),
                  ),
                ),

                // "Looking For" goal tag
                if (profile.lookingFor.isNotEmpty)
                  Positioned(
                    top: 32,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFF4D85).withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4D85).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.cup,
                              color: Color(0xFFFF4D85), size: 14),
                          const SizedBox(width: 8),
                          Text(
                            profile.lookingFor.first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Top Right Info Button
                if (!isBackCard)
                  Positioned(
                    top: 32,
                    right: 14,
                    child: GestureDetector(
                      onTap: onInfoTap,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Iconsax.user,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                // Premium photo navigation buttons (left / right edges)
                if (_showNav)
                  SwipePhotoNav(
                    photoIndex: photoIndex,
                    totalPhotos: totalPhotos,
                    onPrev: onPrevPhoto ?? () {},
                    onNext: onNextPhoto ?? () {},
                  ),

                // Distributed detail chips on subsequent photos
                if (!isBackCard && photoIndex > 0)
                  Positioned(
                    bottom: MediaQuery.of(context).size.height < 680 ? 122 : 140,
                    left: 14,
                    right: 14,
                    child: _buildChippedPhotosOverlay(),
                  ),
              ],
            ),
          ),
        ),

        // Bottom info panel (Inside card)
        Positioned(
          bottom: MediaQuery.of(context).size.height < 680 ? 76 : 92,
          left: 0,
          right: 0,
          child: _buildProfileInfo(context),
        ),

        // Action buttons (inside card, at the bottom)
        if (!isBackCard)
          Positioned(
            bottom: MediaQuery.of(context).size.height < 680 ? 8 : 14,
            left: 0,
            right: 0,
            child: _buildActionRow(context),
          ),
      ],
    );
  }

  /// Picks which detail chips to overlay on each photo.
  Widget _buildChippedPhotosOverlay() {
    final List<Widget> chips = [];

    switch (photoIndex) {
      case 1:
        if (profile.occupation != null && profile.occupation!.isNotEmpty) {
          chips.add(
            _buildInfoChip(icon: Iconsax.briefcase, label: profile.occupation!),
          );
        }
        final education = profile.educationLevel;
        if (education != null && education.isNotEmpty) {
          chips.add(_buildInfoChip(icon: Iconsax.teacher, label: education));
        }
        final school = profile.school;
        if (school != null && school.isNotEmpty) {
          chips.add(_buildInfoChip(icon: Iconsax.book, label: school));
        }
        break;
      case 2:
        for (final hobby in profile.hobbies.take(6)) {
          chips.add(_buildInfoChip(icon: Iconsax.activity, label: hobby));
        }
        break;
      case 3:
        final religion = profile.religion;
        if (religion != null && religion.isNotEmpty) {
          chips.add(_buildInfoChip(icon: Iconsax.global, label: religion));
        }
        final zodiac = profile.zodiac;
        if (zodiac != null && zodiac.isNotEmpty) {
          chips.add(_buildInfoChip(icon: Iconsax.star, label: zodiac));
        }
        break;
      default:
        if (profile.lookingFor.isNotEmpty) {
          chips.add(_buildInfoChip(
            icon: Iconsax.heart,
            label: profile.lookingFor.first,
          ));
        }
        final relationship = profile.relationshipStatus;
        if (relationship != null && relationship.isNotEmpty) {
          chips.add(_buildInfoChip(
            icon: Iconsax.heart_circle,
            label: relationship,
          ));
        }
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }

  Widget _buildProfileInfo(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Padding(
      padding: EdgeInsets.only(
        left: isSmallScreen ? 18 : 22,
        right: isSmallScreen ? 18 : 22,
        bottom: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNameRow(context, isSmallScreen),
          // Only the first photo carries the bio + core chips
          if (photoIndex == 0) ...[
            const SizedBox(height: 6),
            if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  profile.bio!.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Relationship Status chip
                if (profile.relationshipStatus != null &&
                    profile.relationshipStatus!.isNotEmpty)
                  _buildInfoChip(
                    icon: Iconsax.heart,
                    label: profile.relationshipStatus!,
                  ),
                // Distance
                Consumer<ProfileProvider>(
                  builder: (_, profileProvider, _) => _buildInfoChip(
                    icon: Iconsax.location,
                    label:
                        profile.getDistanceDisplay(profileProvider.userProfile),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNameRow(BuildContext context, bool isSmallScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            profile.showAge
                ? '${profile.firstName ?? 'Someone'},'
                : profile.firstName ?? 'Someone',
            style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 24 : 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.1),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (profile.showAge) ...[
          const SizedBox(width: 6),
          Text(
            '${profile.age ?? '??'}',
            style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 22 : 26,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.5),
          ),
        ],
        if (profile.isVerified) ...[
          const SizedBox(width: 6),
          const Icon(Icons.verified_rounded,
              color: Color(0xFF4FC3F7), size: 22),
        ],
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            if (profile.uid != null) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => GiftSelectionSheet(
                  targetUserId: profile.uid!,
                  targetUserName: profile.firstName ?? 'Someone',
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Iconsax.gift, color: Colors.black, size: 16),
                const SizedBox(width: 4),
                Text(
                  languageProvider.getString('send_gift').isNotEmpty
                      ? languageProvider.getString('send_gift')
                      : 'Gift',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 360;

    final primaryBtnSize = isSmallScreen ? 42.0 : 48.0;
    final secondaryBtnSize = isSmallScreen ? 32.0 : 36.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 0,
        top: 4,
        left: isSmallScreen ? 8 : 16,
        right: isSmallScreen ? 8 : 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Rewind
          ActionButton(
            icon: Iconsax.refresh,
            color: canRewind
                ? const Color(0xFF2196F3)
                : Colors.grey.withValues(alpha: 0.5),
            onTap: canRewind ? (onRewind ?? () {}) : () {},
            size: secondaryBtnSize,
            label: languageProvider.getString('rewind'),
          ),
          // 2. Pass
          ActionButton(
            svgAsset: 'assets/images/pass.svg',
            color: const Color(0xFFFF5E5E),
            onTap: onPass ?? () {},
            size: primaryBtnSize,
            label: languageProvider.getString('pass'),
          ),
          // 3. Book (center)
          if (showMeet)
            ActionButton(
              icon: Iconsax.calendar_add,
              color: const Color(0xFFFFA000),
              size: secondaryBtnSize,
              label: 'Meet',
              disabled: !canMeet,
              onTap: onMeet ?? () {},
            ),
          // 4. Like
          ActionButton(
            svgAsset: 'assets/images/like.svg',
            color: const Color(0xFF00C853),
            onTap: onLike ?? () {},
            size: primaryBtnSize,
            label: languageProvider.getString('like'),
          ),
          // 5. Message (conditional, disabled if user disallows messages)
          if (showMessageButton)
            ActionButton(
              icon: Iconsax.message_text_1,
              color: const Color(0xFFFF4D85),
              onTap: onMessage ?? () {},
              size: isSmallScreen ? 34.0 : 40.0,
              label: languageProvider.getString('message'),
              disabled: !canMessage,
            ),
        ],
      ),
    );
  }
}