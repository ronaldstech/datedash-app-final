import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile_model.dart';
import '../providers/profile_provider.dart';
import '../screens/chat_screen.dart';
import '../services/profile_service.dart';
import 'action_button.dart';
import 'profile_detail_sheet.dart';
import '../screens/edit_profile_screen.dart';
import '../providers/language_provider.dart';
import 'gift_selection_sheet.dart';
import 'meetup_sheet.dart';
import '../services/chat_service.dart';

class SwipeView extends StatefulWidget {
  final String? category;
  const SwipeView({super.key, this.category});

  @override
  State<SwipeView> createState() => _SwipeViewState();
}

class _SwipeViewState extends State<SwipeView> with TickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  List<UserProfile> _profiles = [];
  int _currentIndex = 0;
  int _currentPhotoIndex = 0;
  bool _isLoading = true;
  int _lastSwipesVersion = -1;
  int _lastExploreVersion = -1;

  bool _isFetching = false;
  int _freeSwipesUsed = 0; // tracks swipes used when user has < 4 photos

  // Swipe Animation State
  Offset _dragOffset = Offset.zero;
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _swipeController, curve: Curves.easeOutBack));

    _loadProfiles();
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profileProvider = context.watch<ProfileProvider>();
    final user = profileProvider.currentUser;
    final version = profileProvider.swipesVersion;
    final exploreVersion = profileProvider.exploreSwipesVersion;

    // Trigger load if user just became available or version changed
    if (user != null && _profiles.isEmpty && !_isFetching && _isLoading) {
      _loadProfiles();
    }

    if (version != _lastSwipesVersion &&
        _lastSwipesVersion != -1 &&
        widget.category == null) {
      _lastSwipesVersion = version;
      _reload();
    } else {
      _lastSwipesVersion = version;
    }

    if (exploreVersion != _lastExploreVersion &&
        _lastExploreVersion != -1 &&
        widget.category != null) {
      _lastExploreVersion = exploreVersion;
      _reload();
    } else {
      _lastExploreVersion = exploreVersion;
    }
  }

  void _reload() {
    setState(() {
      _profiles = [];
      _currentIndex = 0;
      _currentPhotoIndex = 0;
      _isLoading = true;
    });
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    if (_isFetching) return;

    final profileProvider = context.read<ProfileProvider>();
    final currentUser = profileProvider.currentUser;

    if (currentUser != null) {
      debugPrint('SwipeView: Fetching profiles for UID: ${currentUser.uid}');
      setState(() => _isFetching = true);

      try {
        final profiles = await (widget.category != null
                ? _profileService.getSwipeProfilesByCategory(
                    currentUser.uid, widget.category!)
                : _profileService.getSwipeProfiles(currentUser.uid))
            .timeout(const Duration(seconds: 15)); // Safety timeout

        debugPrint('SwipeView: Fetched ${profiles.length} profiles');
        if (mounted) {
          setState(() {
            _profiles = profiles;
            _isLoading = false;
            _isFetching = false;
          });
        }
      } catch (e) {
        debugPrint('SwipeView: Error loading profiles: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isFetching = false;
          });
        }
      }
    } else {
      debugPrint('SwipeView: No current user yet, retrying in 1.5s...');
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _loadProfiles();
      });
    }
  }

  void _onSwipeComplete(String direction) {
    if (_profiles.isEmpty) return;

    final targetProfile = _profiles[_currentIndex];
    final profileProvider = context.read<ProfileProvider>();
    final currentUserId = profileProvider.currentUser?.uid;
    final swipeType = direction == 'right' ? 'like' : 'dislike';

    // Set last swiped user immediately for instant rewind availability
    profileProvider.setLastSwipedUserId(targetProfile.uid);

    // Update UI immediately (optimistic update)
    setState(() {
      _freeSwipesUsed++;
      if (_currentIndex < _profiles.length - 1) {
        _currentIndex++;
        // Proactive replenishment: fetch more when 2 left
        if (_profiles.length - _currentIndex <= 2) {
          _loadMoreProfiles();
        }
      } else {
        _profiles = [];
        _currentIndex = 0;
      }
      _currentPhotoIndex = 0;
      _dragOffset = Offset.zero;
      _isAnimating = false;
    });

    // Run network write in the background
    if (currentUserId != null && targetProfile.uid != null) {
      _profileService.swipeUser(
        currentUserId,
        targetProfile.uid!,
        swipeType,
        senderName: profileProvider.displayName,
      ).then((isMatch) {
        if (isMatch && mounted) {
          _showMatchDialog(targetProfile);
        }
      }).catchError((e) {
        debugPrint('SwipeView: Error processing swipe in background: $e');
      });
    }
  }

  Future<void> _loadMoreProfiles() async {
    if (_isFetching) return;
    final profileProvider = context.read<ProfileProvider>();
    final currentUser = profileProvider.currentUser;
    if (currentUser == null) return;

    try {
      final newProfiles = widget.category != null
          ? await _profileService.getSwipeProfilesByCategory(
              currentUser.uid, widget.category!)
          : await _profileService.getSwipeProfiles(currentUser.uid);
      if (mounted && newProfiles.isNotEmpty) {
        setState(() {
          final existingIds = _profiles.map((p) => p.uid).toSet();
          final uniqueNew =
              newProfiles.where((p) => !existingIds.contains(p.uid)).toList();
          _profiles.addAll(uniqueNew);
        });
      }
    } catch (e) {
      debugPrint('SwipeView: Error replenishing: $e');
    }
  }

  void _runSwipeAnimation(String direction) {
    if (_isAnimating) return;
    _isAnimating = true;

    final screenWidth = MediaQuery.of(context).size.width;
    final endOffset = direction == 'right'
        ? Offset(screenWidth * 1.5, _dragOffset.dy)
        : Offset(-screenWidth * 1.5, _dragOffset.dy);

    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: endOffset,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));

    _swipeController.forward(from: 0).then((_) {
      _onSwipeComplete(direction);
      context.read<ProfileProvider>().resetSwipeOffset();
      _swipeController.reset();
    });
  }

  void _resetPosition() {
    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _swipeController, curve: Curves.easeOutBack));

    _swipeController.forward(from: 0).then((_) {
      context.read<ProfileProvider>().resetSwipeOffset();
      setState(() {
        _dragOffset = Offset.zero;
        _swipeController.reset();
      });
    });
  }

  void _nextPhoto(int totalPhotos) {
    if (_currentPhotoIndex < totalPhotos - 1) {
      setState(() => _currentPhotoIndex++);
    }
  }

  void _prevPhoto() {
    if (_currentPhotoIndex > 0) {
      setState(() => _currentPhotoIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      color: const Color(0xFFFF4D85),
                      strokeWidth: 3,
                      backgroundColor: const Color(0xFFFF4D85).withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(languageProvider.getString('finding_matches'),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF4D85))),
          ],
        ),
      );
    }

    if (_profiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF4D85).withValues(alpha: 0.15),
                      Colors.transparent
                    ],
                  ),
                ),
                child: Icon(Iconsax.user_search,
                    size: 56, color: const Color(0xFFFF4D85).withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 28),
              Text(languageProvider.getString('no_profiles_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              const SizedBox(height: 12),
              Text(languageProvider.getString('no_profiles_sub'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Theme.of(context).hintColor)),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => _handleResetSwipes(context, languageProvider),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4D85), Color(0xFFFF7DA0)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D85).withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.refresh,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(languageProvider.getString('refresh_profiles'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final profileProvider = context.watch<ProfileProvider>();
    final myPhotos = profileProvider.userProfile?.photos ?? [];
    final hasMinPhotos = myPhotos.length >= 4;
    final isLockedOut = !hasMinPhotos && _freeSwipesUsed >= 1;

    final hasNext = _currentIndex < _profiles.length - 1;
    final profile = _profiles[_currentIndex];
    final nextProfile = hasNext ? _profiles[_currentIndex + 1] : null;

    final photos = profile.photos.isNotEmpty
        ? profile.photos
        : [
            'https://images.unsplash.com/photo-1511367461989-f85a21fda167?q=80&w=800'
          ];
    final photoUrl = _currentPhotoIndex < photos.length
        ? photos[_currentPhotoIndex]
        : photos.first;

    return Padding(
      padding:
          const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 0),
      child: Column(
        children: [
          // --- Engagement Nudge Banner ---
          if (profileProvider.sentLikesCount < 5)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D85).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: const Color(0xFFFF4D85).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.heart5,
                      color: Color(0xFFFF4D85), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      languageProvider
                          .getString('nudge_send_more_likes')
                          .replaceAll('{count}',
                              (5 - profileProvider.sentLikesCount).toString()),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF4D85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedBuilder(
                  animation: _swipeController,
                  builder: (context, _) {
                    final offset = _swipeController.isAnimating
                        ? _swipeAnimation.value
                        : _dragOffset;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final angle = (offset.dx / screenWidth) * 0.45;
                    // Back card reacts to drag: scales up as front card moves
                    final dragFraction =
                        (_dragOffset.dx.abs() / screenWidth).clamp(0.0, 1.0);
                    final backScale = 0.95 + (0.05 * dragFraction);
                    final backOpacity = 0.7 + (0.3 * dragFraction);
                    final backOffset = Offset(0, 12 - (12 * dragFraction));

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (hasNext)
                          Positioned.fill(
                            child: Transform.translate(
                              offset: backOffset,
                              child: Transform.scale(
                                scale: backScale,
                                child: Opacity(
                                  opacity: backOpacity.clamp(0.0, 1.0),
                                  child: _buildCard(
                                    context,
                                    nextProfile!,
                                    nextProfile.photos.isNotEmpty
                                        ? nextProfile.photos.first
                                        : 'https://images.unsplash.com/photo-1511367461989-f85a21fda167?q=80&w=800',
                                    nextProfile.photos.length,
                                    isBackCard: true,
                                    languageProvider: languageProvider,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: GestureDetector(
                            onPanUpdate: isLockedOut
                                ? null
                                : (details) {
                                    if (_isAnimating) return;
                                    setState(
                                        () => _dragOffset += details.delta);
                                    context
                                        .read<ProfileProvider>()
                                        .updateSwipeOffset(_dragOffset.dx);
                                  },
                            onPanEnd: isLockedOut
                                ? null
                                : (details) {
                                    if (_isAnimating) return;
                                    if (_dragOffset.dx > 120) {
                                      _runSwipeAnimation('right');
                                    } else if (_dragOffset.dx < -120)
                                      // ignore: curly_braces_in_flow_control_structures
                                      _runSwipeAnimation('left');
                                    else
                                      // ignore: curly_braces_in_flow_control_structures
                                      _resetPosition();
                                  },
                            child: Transform.translate(
                              offset: offset,
                              child: Transform.rotate(
                                angle: angle,
                                child: Stack(
                                  children: [
                                    _buildCard(
                                      context,
                                      profile,
                                      photoUrl,
                                      photos.length,
                                      onNextPhoto: hasMinPhotos
                                          ? () => _nextPhoto(photos.length)
                                          : _showPhotoLockSnack,
                                      onPrevPhoto: hasMinPhotos
                                          ? _prevPhoto
                                          : _showPhotoLockSnack,
                                      hasMinPhotos: hasMinPhotos,
                                      languageProvider: languageProvider,
                                    ),
                                    IgnorePointer(
                                      child: Stack(
                                        children: [
                                          Positioned(
                                            top: 56,
                                            left: 24,
                                            child: Transform.rotate(
                                              angle: -0.35,
                                              child: Opacity(
                                                opacity: (offset.dx / 100)
                                                    .clamp(0.0, 1.0),
                                                child: _buildStamp(
                                                    'assets/images/like.svg',
                                                    const Color(0xFF00C853)),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 56,
                                            right: 24,
                                            child: Transform.rotate(
                                              angle: 0.35,
                                              child: Opacity(
                                                opacity: (-offset.dx / 100)
                                                    .clamp(0.0, 1.0),
                                                child: _buildStamp(
                                                    'assets/images/pass.svg',
                                                    const Color(0xFFFF5E5E)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Locked overlay after 1 free swipe
                        if (isLockedOut)
                          Positioned.fill(
                            child: _buildLockedOverlay(languageProvider),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, UserProfile profile, String photoUrl,
      int totalPhotos,
      {bool isBackCard = false,
      VoidCallback? onNextPhoto,
      VoidCallback? onPrevPhoto,
      bool hasMinPhotos = true,
      required LanguageProvider languageProvider}) {
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
                // Dark background – always visible, prevents back card bleed-through during photo loads
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
                    errorBuilder: (_, __, ___) =>
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

                // Photo indicators — Positioned MUST be direct child of Stack
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
                                  height: index == _currentPhotoIndex ? 4 : 3,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: index == _currentPhotoIndex
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: index == _currentPhotoIndex
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

                // "Looking For" goal tag — replaces common interests for clarity
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

                // Top Right Buttons (Gift & Info)
                if (!isBackCard)
                  Positioned(
                    top: 32,
                    right: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Gift Button
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => GiftSelectionSheet(
                                targetUserId: profile.uid!,
                                targetUserName: profile.firstName ?? 'Someone',
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Iconsax.gift,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Info/Details Button
                        GestureDetector(
                          onTap: () => _showProfileDetails(profile),
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
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Bottom info panel (Inside card)
        Positioned(
          bottom: 96,
          left: 0,
          right: 0,
          child: _buildProfileInfo(context, profile,
              hasMinPhotos: hasMinPhotos && !isBackCard,
              languageProvider: languageProvider),
        ),

        // Action buttons (inside card, at the bottom)
        if (!isBackCard)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: _buildActionRow(languageProvider),
          ),
      ],
    );
  }

  Widget _buildActionRow(LanguageProvider languageProvider) {
    final profileProvider = context.watch<ProfileProvider>();
    final canRewind =
        profileProvider.lastSwipedUserId != null && _currentIndex > 0;
    final currentProfile =
        _profiles.isNotEmpty ? _profiles[_currentIndex] : null;
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 0, top: 4, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Rewind
          ActionButton(
            icon: Iconsax.refresh,
            color: canRewind
                ? const Color(0xFF2196F3)
                : Colors.grey.withValues(alpha: 0.5),
            onTap: canRewind ? _handleRewind : () {},
            size: 36,
            label: languageProvider.getString('rewind'),
          ),
          // 2. Pass
          ActionButton(
            svgAsset: 'assets/images/pass.svg',
            color: const Color(0xFFFF5E5E),
            onTap: () => _runSwipeAnimation('left'),
            size: 48,
            label: languageProvider.getString('pass'),
          ),
          // 3. Book (center)
          if (currentProfile != null &&
              currentProfile.uid != null &&
              myUid != null)
            ActionButton(
              icon: Iconsax.calendar_add,
              color: const Color(0xFFFFA000),
              size: 36,
              label: 'Meet',
              disabled: !currentProfile.allowMeetupRequests,
              onTap: () {
                final chatId = ChatService()
                    .getChatId(myUid, currentProfile.uid!);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => MeetupSheet(
                    otherUserId: currentProfile.uid!,
                    otherUserName:
                        currentProfile.firstName ?? 'Someone',
                    chatId: chatId,
                    myUid: myUid,
                  ),
                );
              },
            ),
          // 4. Like
          ActionButton(
            svgAsset: 'assets/images/like.svg',
            color: const Color(0xFF00C853),
            onTap: () => _runSwipeAnimation('right'),
            size: 48,
            label: languageProvider.getString('like'),
          ),
          // 5. Message (conditional, disabled if user disallows messages)
          if (profileProvider.sentLikesCount >= 5)
            ActionButton(
              icon: Iconsax.message_text_1,
              color: const Color(0xFFFF4D85),
              onTap: () => _handleDirectMessage(languageProvider),
              size: 40,
              label: languageProvider.getString('message'),
              disabled: currentProfile != null && !currentProfile.allowMessages,
            ),
        ],
      ),
    );
  }

  Future<void> _handleDirectMessage(LanguageProvider lp) async {
    final profileProvider = context.read<ProfileProvider>();
    final targetProfile = _profiles[_currentIndex];
    final myUid = profileProvider.currentUser?.uid;

    if (myUid == null || targetProfile.uid == null) return;

    if (!targetProfile.allowMessages) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lp.getString('messages_disabled_snack'))));
      return;
    }

    // Navigate instantly, ChatScreen handles its own initialization
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            otherUserId: targetProfile.uid!,
            otherUserName:
                targetProfile.firstName ?? lp.getString('user_fallback'),
            otherUserPhoto: targetProfile.photos.isNotEmpty
                ? targetProfile.photos.first
                : null,
          ),
        ),
      );
    }
  }

  Future<void> _handleRewind() async {
    final languageProvider = context.read<LanguageProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final lastId = profileProvider.lastSwipedUserId;

    if (lastId == null || _currentIndex <= 0) return;

    // Premium users rewind for free
    if (profileProvider.userProfile?.isPremium == true) {
      _executeRewind();
      return;
    }

    // Non-premium users must use 100 credits
    final userCredits = profileProvider.userProfile?.credits ?? 0;
    if (userCredits >= 100) {
      _showRewindConfirmationDialog(languageProvider, profileProvider);
    } else {
      _showInsufficientCreditsDialog(languageProvider);
    }
  }

  void _showRewindConfirmationDialog(
      LanguageProvider languageProvider, ProfileProvider profileProvider) {
    bool isRewinding = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Premium Header with Icon
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2196F3).withValues(alpha: 0.2),
                        const Color(0xFF2196F3).withValues(alpha: 0.02),
                      ],
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Decorative circles
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2196F3).withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      const Icon(
                        Iconsax.refresh,
                        size: 64,
                        color: Color(0xFF2196F3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  languageProvider.getString('rewind_confirm_title'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    languageProvider.getString('rewind_confirm_message'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).hintColor,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: isRewinding
                                  ? null
                                  : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                languageProvider.getString('cancel'),
                                style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isRewinding
                                  ? null
                                  : () async {
                                      setDialogState(() => isRewinding = true);
                                      try {
                                        await _executeRewind(useCredits: 100);
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          setDialogState(
                                              () => isRewinding = false);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text('Error: $e')),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2196F3),
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor:
                                    const Color(0xFF2196F3).withValues(alpha: 0.4),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isRewinding
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      languageProvider
                                          .getString('confirm_button'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isRewinding
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  profileProvider.navigateToPremium(0);
                                },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(
                                color: Color(0xFFFF4D85), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            languageProvider.getString('go_premium'),
                            style: const TextStyle(
                              color: Color(0xFFFF4D85),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
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
        ),
      ),
    );
  }

  void _showInsufficientCreditsDialog(LanguageProvider languageProvider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium Header with Icon
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFB300).withValues(alpha: 0.2),
                      const Color(0xFFFFB300).withValues(alpha: 0.02),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFB300).withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    const Icon(
                      Iconsax.coin,
                      size: 64,
                      color: Color(0xFFFFB300),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                languageProvider.getString('insufficient_credits_title'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  languageProvider.getString('insufficient_credits_message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).hintColor,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              languageProvider.getString('cancel'),
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context
                                  .read<ProfileProvider>()
                                  .navigateToPremium(1);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB300),
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor:
                                  const Color(0xFFFFB300).withValues(alpha: 0.4),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              languageProvider.getString('get_credits_button'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<ProfileProvider>().navigateToPremium(0);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(
                              color: Color(0xFFFF4D85), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          languageProvider.getString('go_premium'),
                          style: const TextStyle(
                            color: Color(0xFFFF4D85),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
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
      ),
    );
  }

  Future<void> _executeRewind({int? useCredits}) async {
    final profileProvider = context.read<ProfileProvider>();
    try {
      if (useCredits != null) {
        await profileProvider.useCredits(useCredits);
      }

      await profileProvider.rewindSwipe();
      setState(() {
        _currentIndex--;
        if (_freeSwipesUsed > 0) _freeSwipesUsed--;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('SwipeView: Rewind error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to rewind profile')),
        );
      }
    }
  }

  Widget _buildProfileInfo(BuildContext context, UserProfile profile,
      {bool hasMinPhotos = true, required LanguageProvider languageProvider}) {
    final occupation = profile.occupation;
    final school = profile.school;
    final hobbies = profile.hobbies;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Name & Age ──────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  profile.showAge
                      ? '${profile.firstName ?? 'Someone'},'
                      : profile.firstName ?? 'Someone',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.1),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (profile.showAge) ...[
                const SizedBox(width: 8),
                Text(
                  '${profile.age ?? '??'}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.5),
                ),
              ],
              if (profile.isVerified) ...[
                const SizedBox(width: 8),
                const Icon(Icons.verified_rounded,
                    color: Color(0xFF4FC3F7), size: 24)
              ],
            ],
          ),
          const SizedBox(height: 4),

          //Professional Info & Distance (Wrapped Chips)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Occupation / Work
              if (occupation != null && occupation.isNotEmpty)
                _buildInfoChip(
                  icon: Iconsax.briefcase,
                  label: occupation,
                ),

              // School / Education
              if (school != null && school.isNotEmpty)
                _buildInfoChip(
                  icon: Iconsax.book,
                  label: school,
                ),

              // Distance
              Consumer<ProfileProvider>(
                builder: (_, profileProvider, __) => _buildInfoChip(
                  icon: Iconsax.location,
                  label:
                      profile.getDistanceDisplay(profileProvider.userProfile),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // ── Hobbies / Interests (Horizontal Scroll) ─────────────────
          if (hobbies.isNotEmpty)
            SizedBox(
              height: 24,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: hobbies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D85).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFF4D85).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    hobbies[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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

  Widget _buildLockedOverlay(LanguageProvider languageProvider) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: Colors.black.withValues(alpha: 0.55),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D85).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF4D85).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Color(0xFFFF4D85),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    languageProvider.getString('upload_more_photos_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    languageProvider.getString('upload_more_photos_sub'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4D85), Color(0xFFFF7DA0)],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4D85).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text(
                        languageProvider.getString('add_photos_now'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStamp(String svgAsset, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 4),
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16)],
      ),
      child: SvgPicture.asset(
        svgAsset,
        width: 56,
        height: 56,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }

  void _showProfileDetails(UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileDetailSheet(
        profile: profile,
        onLike: () {
          Navigator.pop(context);
          _runSwipeAnimation('right');
        },
        onDislike: () {
          Navigator.pop(context);
          _runSwipeAnimation('left');
        },
        onMessage: () async {
          if (!profile.allowMessages) {
            _showPremiumSnack(context
                .read<LanguageProvider>()
                .getString('messages_disabled_snack'));
            return;
          }
          Navigator.pop(context);
          final myUid = FirebaseAuth.instance.currentUser?.uid;
          if (myUid == null || profile.uid == null) return;
          if (mounted) {
            Navigator.push(
                this.context,
                MaterialPageRoute(
                    builder: (_) => ChatScreen(
                          otherUserId: profile.uid!,
                          otherUserName: profile.firstName ?? 'User',
                          otherUserPhoto: profile.photos.isNotEmpty
                              ? profile.photos.first
                              : null,
                        )));
          }
        },
      ),
    );
  }

  void _showPhotoLockSnack() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  context
                      .read<LanguageProvider>()
                      .getString('photo_lock_snack'),
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
      backgroundColor: const Color(0xFFFF4D85),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.all(20),
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: context.read<LanguageProvider>().getString('upload_label'),
        textColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
          );
        },
      ),
    ));
  }

  void _showPremiumSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFFFF4D85),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.all(20),
    ));
  }

  Future<void> _handleResetSwipes(
      BuildContext context, LanguageProvider lp) async {
    final profileProvider = context.read<ProfileProvider>();
    final isPremium = profileProvider.userProfile?.isPremium ?? false;

    if (isPremium) {
      await profileProvider.resetSwipes();
      _reload();
      return;
    }

    // Non-premium: Confirm 50 credit charge
    if (!context.mounted) return;

    final credits = profileProvider.userProfile?.credits ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Iconsax.refresh, color: Color(0xFFFF4D85)),
            const SizedBox(width: 10),
            Text(lp.getString('refresh_cost_title'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          lp
              .getString('refresh_cost_content')
              .replaceAll('{credits}', credits.toString()),
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lp.getString('cancel'),
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
              if (credits < 50) {
                _showPremiumSnack(lp.getString('not_enough_credits'));
                return;
              }

              try {
                await profileProvider.useCredits(50);
                await profileProvider.resetSwipes();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lp.getString('swipes_reset_success')),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
                _reload();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lp.getString('swipes_reset_failed')),
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
            child: Text(lp.getString('pay_refresh'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showMatchDialog(UserProfile otherProfile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: const Color(0xFFFF4D85).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D85).withValues(alpha: 0.15),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'IT\'S A MATCH!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFF4D85),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You and ${otherProfile.firstName} liked each other.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // My Avatar (Consumer to get current user photo)
                  Consumer<ProfileProvider>(
                    builder: (context, provider, _) {
                      final myPhoto =
                          provider.userProfile?.photos.isNotEmpty == true
                              ? provider.userProfile!.photos.first
                              : null;
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          image: myPhoto != null
                              ? DecorationImage(
                                  image: NetworkImage(myPhoto),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: myPhoto == null
                            ? const Icon(Icons.person,
                                color: Colors.white, size: 40)
                            : null,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  const Icon(Iconsax.heart5,
                      color: Color(0xFFFF4D85), size: 32),
                  const SizedBox(width: 12),
                  // Other User Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      image: otherProfile.photos.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(otherProfile.photos.first),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: otherProfile.photos.isEmpty
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 40)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        otherUserId: otherProfile.uid!,
                        otherUserName: otherProfile.firstName ?? 'User',
                        otherUserPhoto: otherProfile.photos.isNotEmpty
                            ? otherProfile.photos.first
                            : null,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D85),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  elevation: 8,
                  shadowColor: const Color(0xFFFF4D85).withValues(alpha: 0.4),
                ),
                child: const Text(
                  'SEND A MESSAGE',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'KEEP SWIPING',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
