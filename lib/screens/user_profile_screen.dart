import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../models/user_profile_model.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../services/profile_service.dart';
import '../widgets/meetup_sheet.dart';
import '../services/chat_service.dart';

class UserProfileScreen extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onMessage;

  const UserProfileScreen({
    super.key,
    required this.profile,
    required this.onLike,
    required this.onDislike,
    required this.onMessage,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  int _currentPhotoIndex = 0;
  late PageController _pageController;
  bool _isMatched = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPhotoIndex);

    // Record profile view
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    _currentUserId = profileProvider.currentUser?.uid;
    if (_currentUserId != null && widget.profile.uid != null) {
      ProfileService().recordProfileView(_currentUserId!, widget.profile.uid!,
          senderName: profileProvider.displayName);
      _checkMatch();
    }
  }

  Future<void> _checkMatch() async {
    if (_currentUserId != null && widget.profile.uid != null) {
      final matched = await ProfileService().checkMatchStatus(_currentUserId!, widget.profile.uid!);
      if (mounted) {
        setState(() => _isMatched = matched);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPhoto(int totalPhotos) {
    if (_currentPhotoIndex < totalPhotos - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPhoto() {
    if (_currentPhotoIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF4D85);
    final photos = widget.profile.photos.isNotEmpty 
        ? widget.profile.photos 
        : ['https://images.unsplash.com/photo-1511367461989-f85a21fda167?q=80&w=800'];

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Parallax Header ───────────────────────────────────
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.6,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.black,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 	0.3),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Photo Carousel Logic
                      PageView.builder(
                        controller: _pageController,
                        itemCount: photos.length,
                        onPageChanged: (index) =>
                            setState(() => _currentPhotoIndex = index),
                        itemBuilder: (context, index) => Image.network(
                          photos[index],
                          fit: BoxFit.cover,
                        ),
                      ),

                      // Gradient Overlay
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black54,
                            ],
                            stops: [0.6, 1.0],
                          ),
                        ),
                      ),

                      // Photo Indicators
                      if (photos.length > 1)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 60,
                          left: 20,
                          right: 20,
                          child: Row(
                            children: List.generate(
                              photos.length,
                              (index) => Expanded(
                                child: Container(
                                  height: 3,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: index == _currentPhotoIndex
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 	0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Edge Taps Navigation (Top Layer)
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) {
                          final width = MediaQuery.of(context).size.width;
                          if (details.localPosition.dx < width * 0.4) {
                            _prevPhoto();
                          } else if (details.localPosition.dx > width * 0.6) {
                            _nextPhoto(photos.length);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Profile Content ───────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.profile.showAge
                                      ? '${widget.profile.firstName ?? 'Someone'}, ${widget.profile.age ?? '??'}'
                                      : widget.profile.firstName ?? 'Someone',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Consumer<ProfileProvider>(
                                  builder: (context, profileProvider, _) {
                                    return Row(
                                      children: [
                                        const Icon(Iconsax.location, color: primaryColor, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          widget.profile.getDistanceDisplay(profileProvider.userProfile),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (widget.profile.isVerified)
                            const Icon(Icons.verified, color: Colors.blueAccent, size: 36),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // About Me
                      if (widget.profile.bio?.isNotEmpty ?? false) ...[
                        const _SectionHeader(title: 'About Me', icon: Iconsax.user),
                        Text(
                          widget.profile.bio!,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 	0.8),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Quick Facts
                      _buildQuickFacts(context),
                      const SizedBox(height: 32),

                      // Relationship Goals
                      if (widget.profile.lookingFor.isNotEmpty) ...[
                        const _SectionHeader(title: 'Relationship Goals', icon: Iconsax.heart),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: widget.profile.lookingFor
                              .map((g) => _Chip(label: g, color: primaryColor))
                              .toList(),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Work & Education
                      _buildWorkEdu(context),
                      const SizedBox(height: 32),

                      // Interests & Hobbies
                      if (widget.profile.hobbies.isNotEmpty) ...[
                        const _SectionHeader(title: 'Interests & Hobbies', icon: Iconsax.activity),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: widget.profile.hobbies
                              .map((h) => _Chip(label: h))
                              .toList(),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Lifestyle
                      _buildLifestyle(context),
                      const SizedBox(height: 32),

                      // Prompts
                      _buildPrompts(context),

                      const SizedBox(height: 120), // Padding for buttons
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Action Buttons ──────────────────────────────────────
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 	0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: Iconsax.close_circle,
                    color: const Color(0xFFFF5E5E),
                    onTap: widget.onDislike,
                  ),
                  _ActionButton(
                    icon: Iconsax.heart5,
                    color: primaryColor,
                    onTap: widget.onLike,
                  ),
                  if (_isMatched && widget.profile.allowMeetupRequests)
                    _ActionButton(
                      icon: Iconsax.calendar_add,
                      color: const Color(0xFFFFA000),
                      onTap: () {
                        if (_currentUserId != null && widget.profile.uid != null) {
                          final chatId = ChatService().getChatId(_currentUserId!, widget.profile.uid!);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => MeetupSheet(
                              otherUserId: widget.profile.uid!,
                              otherUserName: widget.profile.firstName ?? 'Someone',
                              chatId: chatId,
                              myUid: _currentUserId!,
                            ),
                          );
                        }
                      },
                      isSmall: true,
                    ),
                  _ActionButton(
                    icon: Iconsax.message_text5,
                    color: Colors.blueAccent,
                    onTap: widget.onMessage,
                    isSmall: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFacts(BuildContext context) {
    final items = <_LabeledRow>[];
    if (widget.profile.height != null) items.add(_LabeledRow(icon: Iconsax.ruler, label: 'Height', value: widget.profile.height!));
    if (widget.profile.educationLevel != null) items.add(_LabeledRow(icon: Iconsax.teacher, label: 'Education', value: widget.profile.educationLevel!));
    if (widget.profile.religion != null) items.add(_LabeledRow(icon: Iconsax.cloud, label: 'Religion', value: widget.profile.religion!));
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const _SectionHeader(title: 'Quick Facts', icon: Iconsax.info_circle),
        ...items,
      ],
    );
  }

  Widget _buildWorkEdu(BuildContext context) {
    final items = <_LabeledRow>[];
    if (widget.profile.occupation != null) items.add(_LabeledRow(icon: Iconsax.briefcase, label: 'Occupation', value: widget.profile.occupation!));
    if (widget.profile.school != null) items.add(_LabeledRow(icon: Iconsax.book, label: 'School', value: widget.profile.school!));
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const _SectionHeader(title: 'Work & Education', icon: Iconsax.profile_2user),
        ...items,
      ],
    );
  }

  Widget _buildLifestyle(BuildContext context) {
    final items = <_LabeledRow>[];
    if (widget.profile.smoking != null) items.add(_LabeledRow(icon: Iconsax.status, label: 'Smoking', value: widget.profile.smoking!));
    if (widget.profile.drinking != null) items.add(_LabeledRow(icon: Iconsax.cup, label: 'Drinking', value: widget.profile.drinking!));
    if (widget.profile.fitness != null) items.add(_LabeledRow(icon: Iconsax.activity, label: 'Exercise', value: widget.profile.fitness!));
    if (widget.profile.diet != null) items.add(_LabeledRow(icon: Iconsax.coffee, label: 'Diet', value: widget.profile.diet!));
    if (widget.profile.sleepingHabits != null) items.add(_LabeledRow(icon: Iconsax.moon, label: 'Sleep', value: widget.profile.sleepingHabits!));
    if (widget.profile.pets != null && widget.profile.pets!.isNotEmpty) items.add(_LabeledRow(icon: Icons.pets, label: 'Pets', value: widget.profile.pets!));
    if (widget.profile.zodiac != null && widget.profile.zodiac!.isNotEmpty) items.add(_LabeledRow(icon: Icons.stars, label: 'Zodiac', value: widget.profile.zodiac!));
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const _SectionHeader(title: 'Lifestyle', icon: Iconsax.chart_2),
        ...items,
      ],
    );
  }

  Widget _buildPrompts(BuildContext context) {
    final prompts = <Map<String, String?>>[
      {'q': 'The perfect date', 'a': widget.profile.promptPerfectDate},
      {'q': 'You\'ll fall for me if', 'a': widget.profile.promptFallForYou},
      {'q': 'My green flag', 'a': widget.profile.promptGreenFlag},
    ].where((p) => p['a']?.isNotEmpty ?? false).toList();

    if (prompts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const _SectionHeader(title: 'Prompts', icon: Iconsax.message_question),
        ...prompts.map((p) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 	0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p['q']!,
                style: const TextStyle(color: Color(0xFFFF4D85), fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                p['a']!,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
        )),
      ],
    );
  }
}

// ── Shared Sub-widgets ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFFF4D85)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _LabeledRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFFF4D85).withValues(alpha: 	0.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: const Color(0xFFFF4D85)),
          ),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;
  const _Chip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFFFF4D85);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 	0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 	0.2)),
      ),
      child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isSmall;

  const _ActionButton({required this.icon, required this.color, required this.onTap, this.isSmall = false});

  @override
  Widget build(BuildContext context) {
    final size = isSmall ? 56.0 : 68.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).cardColor,
          border: Border.all(color: color.withValues(alpha: 	0.2), width: 2),
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }
}

