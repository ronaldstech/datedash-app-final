import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/user_profile_model.dart';
import '../providers/profile_provider.dart';
import '../screens/user_profile_screen.dart';
import '../services/profile_service.dart';
import '../providers/language_provider.dart';

class ProfileDetailSheet extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onMessage;

  const ProfileDetailSheet({
    super.key,
    required this.profile,
    required this.onLike,
    required this.onDislike,
    required this.onMessage,
  });

  @override
  State<ProfileDetailSheet> createState() => _ProfileDetailSheetState();
}

class _ProfileDetailSheetState extends State<ProfileDetailSheet> {
  @override
  void initState() {
    super.initState();
    // Record profile view once when the sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final profileProvider = context.read<ProfileProvider>();
        final currentUserId = profileProvider.currentUser?.uid;
        if (currentUserId != null && widget.profile.uid != null) {
          ProfileService().recordProfileView(currentUserId, widget.profile.uid!,
              senderName: profileProvider.displayName);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF4D85);
    final profileProvider = context.watch<ProfileProvider>();
    final profile = widget.profile;
    final onLike = widget.onLike;
    final onDislike = widget.onDislike;
    final onMessage = widget.onMessage;
    final languageProvider = context.watch<LanguageProvider>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 130),
                  children: [
                    // ── Header ──────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.showAge
                                    ? '${profile.firstName ?? 'Someone'}, ${profile.age ?? '??'}'
                                    : profile.firstName ?? 'Someone',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (profile.occupation != null ||
                                  profile.industry != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Iconsax.briefcase,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        [
                                          if (profile.occupation != null)
                                            profile.occupation,
                                          if (profile.industry != null)
                                            profile.industry,
                                        ].join(' · '),
                                        style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Iconsax.location,
                                      color: primaryColor, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    profile.getDistanceDisplay(
                                        profileProvider.userProfile),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (profile.isVerified)
                          const Icon(Icons.verified,
                              color: Colors.blueAccent, size: 32),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── View Full Profile Button ────────────────────────
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(
                              profile: profile,
                              onLike: () {
                                final profileProvider =
                                    context.read<ProfileProvider>();
                                final myUid = profileProvider.currentUser?.uid;
                                if (myUid != null && profile.uid != null) {
                                  ProfileService().swipeUser(
                                      myUid, profile.uid!, 'like',
                                      senderName: profileProvider.displayName);
                                }
                                Navigator.pop(context);
                                onLike.call();
                              },
                              onDislike: () {
                                final profileProvider =
                                    context.read<ProfileProvider>();
                                final myUid = profileProvider.currentUser?.uid;
                                if (myUid != null && profile.uid != null) {
                                  ProfileService().swipeUser(
                                      myUid, profile.uid!, 'dislike',
                                      senderName: profileProvider.displayName);
                                }
                                Navigator.pop(context);
                                onDislike.call();
                              },
                              onMessage: onMessage,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              primaryColor,
                              Color(0xFFFF7B9B),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.35),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Iconsax.profile_2user,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              languageProvider.getString('view_full_profile'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── About Me ────────────────────────────────────
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      _SectionHeader(
                          title: languageProvider.getString('about_me'),
                          icon: Iconsax.user),
                      Text(
                        profile.bio!,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.color
                              ?.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // ── Quick Facts ─────────────────────────────────
                    _buildQuickFacts(context),
                    const SizedBox(height: 28),

                    // ── Personal Details ────────────────────────────
                    _buildPersonalDetails(context),

                    // ── Lifestyle ───────────────────────────────────
                    _buildLifestyle(context),

                    // ── Relationship Goals ──────────────────────────
                    if (profile.lookingFor.isNotEmpty) ...[
                      _SectionHeader(
                          title:
                              languageProvider.getString('relationship_goals'),
                          icon: Iconsax.heart),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.lookingFor
                            .map((g) => _Chip(label: g, color: primaryColor))
                            .toList(),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // ── Interests & Hobbies ─────────────────────────
                    if (profile.hobbies.isNotEmpty) ...[
                      _SectionHeader(
                          title:
                              languageProvider.getString('interests_hobbies'),
                          icon: Iconsax.activity),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.hobbies
                            .map((h) => _Chip(label: h))
                            .toList(),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // ── Music ───────────────────────────────────────
                    if (profile.musicGenres.isNotEmpty) ...[
                      _SectionHeader(
                          title: languageProvider.getString('music_taste'),
                          icon: Iconsax.music),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: profile.musicGenres
                            .map((g) => _Chip(label: g))
                            .toList(),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // ── Personality ─────────────────────────────────
                    _buildPersonality(context),

                    // ── Prompts ─────────────────────────────────────
                    _buildPrompts(context),
                  ],
                ),
              ),
            ],
          ),

          // ── Action Buttons fixed at bottom ────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    svgAsset: 'assets/images/pass.svg',
                    color: const Color(0xFFFF5E5E),
                    label: languageProvider.getString('pass'),
                    onTap: onDislike,
                  ),
                  _ActionButton(
                    icon: Iconsax.heart5,
                    color: primaryColor,
                    label: languageProvider.getString('like'),
                    onTap: onLike,
                  ),
                  _ActionButton(
                    icon: Iconsax.message_text5,
                    color: Colors.blueAccent,
                    label: languageProvider.getString('message'),
                    onTap: onMessage,
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
    final facts = <Map<String, dynamic>>[];
    if (widget.profile.height != null) {
      facts.add({
        'icon': Iconsax.ruler,
        'label': context.read<LanguageProvider>().getString('height_label'),
        'value': widget.profile.height!
      });
    }
    if (widget.profile.educationLevel != null) {
      facts.add({
        'icon': Iconsax.teacher,
        'label': context.read<LanguageProvider>().getString('education_label'),
        'value': widget.profile.educationLevel!
      });
    }
    if (widget.profile.religion != null) {
      facts.add({
        'icon': Iconsax.cloud,
        'label': context.read<LanguageProvider>().getString('religion_label'),
        'value': widget.profile.religion!
      });
    }
    if (widget.profile.wantKids != null) {
      facts.add({
        'icon': Iconsax.heart_circle,
        'label': context.read<LanguageProvider>().getString('wants_kids_label'),
        'value': widget.profile.wantKids!
      });
    }
    if (widget.profile.openToLongDistance != null) {
      facts.add({
        'icon': Iconsax.global,
        'label':
            context.read<LanguageProvider>().getString('long_distance_label'),
        'value': widget.profile.openToLongDistance! ? 'Open to it' : 'No'
      });
    }

    if (facts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        _SectionHeader(
            title: context.read<LanguageProvider>().getString('quick_facts'),
            icon: Iconsax.info_circle),
        ...facts.map(
          (f) => _LabeledRow(
            icon: f['icon'] as IconData,
            label: f['label'] as String,
            value: f['value'] as String,
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildPersonalDetails(BuildContext context) {
    final items = <Map<String, dynamic>>[];
    if (widget.profile.bodyType != null) {
      items.add({
        'icon': Iconsax.user,
        'label': context.read<LanguageProvider>().getString('body_type_label'),
        'value': widget.profile.bodyType!
      });
    }
    if (widget.profile.relationshipStatus != null) {
      items.add({
        'icon': Iconsax.heart,
        'label': context.read<LanguageProvider>().getString('status_label'),
        'value': widget.profile.relationshipStatus!
      });
    }
    if (widget.profile.school != null) {
      items.add({
        'icon': Iconsax.book,
        'label': context.read<LanguageProvider>().getString('school_label'),
        'value': widget.profile.school!
      });
    }
    if (widget.profile.languages.isNotEmpty) {
      items.add({
        'icon': Iconsax.translate,
        'label': context
            .read<LanguageProvider>()
            .getString('languages_spoken_label'),
        'value': widget.profile.languages.join(', ')
      });
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        _SectionHeader(
            title: context.read<LanguageProvider>().getString('background'),
            icon: Iconsax.profile_2user),
        ...items.map(
          (f) => _LabeledRow(
            icon: f['icon'] as IconData,
            label: f['label'] as String,
            value: f['value'] as String,
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildLifestyle(BuildContext context) {
    final items = <Map<String, dynamic>>[];
    if (widget.profile.smoking != null) {
      items.add({
        'icon': Iconsax.status,
        'label': context.read<LanguageProvider>().getString('smoking_label'),
        'value': widget.profile.smoking!
      });
    }
    if (widget.profile.drinking != null) {
      items.add({
        'icon': Iconsax.cup,
        'label': context.read<LanguageProvider>().getString('drinking_label'),
        'value': widget.profile.drinking!
      });
    }
    if (widget.profile.fitness != null) {
      items.add({
        'icon': Iconsax.activity,
        'label': context.read<LanguageProvider>().getString('exercise_label'),
        'value': widget.profile.fitness!
      });
    }
    if (widget.profile.diet != null) {
      items.add({
        'icon': Iconsax.coffee,
        'label': context.read<LanguageProvider>().getString('diet_label'),
        'value': widget.profile.diet!
      });
    }
    if (widget.profile.sleepingHabits != null) {
      items.add({
        'icon': Iconsax.moon,
        'label': context.read<LanguageProvider>().getString('sleep_label'),
        'value': widget.profile.sleepingHabits!
      });
    }
    if (widget.profile.pets != null && widget.profile.pets!.isNotEmpty) {
      items.add({
        'icon': Icons.pets,
        'label': context.read<LanguageProvider>().getString('pets_label'),
        'value': widget.profile.pets!
      });
    }
    if (widget.profile.zodiac != null && widget.profile.zodiac!.isNotEmpty) {
      items.add({
        'icon': Icons.stars,
        'label': context.read<LanguageProvider>().getString('zodiac_label'),
        'value': widget.profile.zodiac!
      });
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        _SectionHeader(
            title: context.read<LanguageProvider>().getString('lifestyle'),
            icon: Iconsax.chart_2),
        ...items.map(
          (f) => _LabeledRow(
            icon: f['icon'] as IconData,
            label: f['label'] as String,
            value: f['value'] as String,
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildPersonality(BuildContext context) {
    final items = <Map<String, dynamic>>[];
    if (widget.profile.mbti != null) {
      items.add({
        'icon': Iconsax.profile_circle,
        'label': context
            .read<LanguageProvider>()
            .getString('personality_type_label'),
        'value': widget.profile.mbti!
      });
    }
    if (widget.profile.introvertExtrovert != null) {
      items.add({
        'icon': Iconsax.sun_1,
        'label':
            context.read<LanguageProvider>().getString('social_style_label'),
        'value': widget.profile.introvertExtrovert!
      });
    }
    if (widget.profile.loveLanguage != null) {
      items.add({
        'icon': Iconsax.heart,
        'label':
            context.read<LanguageProvider>().getString('love_language_label'),
        'value': widget.profile.loveLanguage!
      });
    }
    if (widget.profile.coreValues != null) {
      items.add({
        'icon': Iconsax.star,
        'label':
            context.read<LanguageProvider>().getString('core_values_label'),
        'value': widget.profile.coreValues!
      });
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        _SectionHeader(
            title: context.read<LanguageProvider>().getString('personality'),
            icon: Iconsax.emoji_happy),
        ...items.map(
          (f) => _LabeledRow(
            icon: f['icon'] as IconData,
            label: f['label'] as String,
            value: f['value'] as String,
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildPrompts(BuildContext context) {
    final prompts = <Map<String, String?>>[
      {'q': 'The perfect date', 'a': widget.profile.promptPerfectDate},
      {'q': 'You\'ll fall for me if', 'a': widget.profile.promptFallForYou},
      {'q': 'My green flag', 'a': widget.profile.promptGreenFlag},
      {'q': 'Two truths & a lie', 'a': widget.profile.promptTwoTruths},
    ].where((p) => p['a'] != null && p['a']!.isNotEmpty).toList();

    if (prompts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
            title: context.read<LanguageProvider>().getString('prompts'),
            icon: Iconsax.message_question),
        ...prompts.map(
          (p) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['q']!,
                  style: const TextStyle(
                    color: Color(0xFFFF4D85),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p['a']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFFF4D85)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _LabeledRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D85).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFFFF4D85)),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final String? svgAsset;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool isSmall;

  const _ActionButton({
    this.icon,
    this.svgAsset,
    required this.color,
    required this.label,
    required this.onTap,
    this.isSmall = false,
  }) : assert(icon != null || svgAsset != null);

  @override
  Widget build(BuildContext context) {
    final size = isSmall ? 54.0 : 64.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
            ),
            child: Center(
              child: svgAsset != null
                  ? SvgPicture.asset(
                      svgAsset!,
                      width: size * 0.45,
                      height: size * 0.45,
                      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                    )
                  : Icon(icon, color: color, size: size * 0.42),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }
}

// Keep legacy exports for backward compatibility
class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});
  @override
  Widget build(BuildContext context) =>
      _SectionHeader(title: title, icon: Iconsax.info_circle);
}

class InfoTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const InfoTag({super.key, required this.icon, required this.label});
  @override
  Widget build(BuildContext context) =>
      _LabeledRow(icon: icon, label: label, value: '');
}

class DetailChip extends StatelessWidget {
  final String label;
  final Color? color;
  const DetailChip({super.key, required this.label, this.color});
  @override
  Widget build(BuildContext context) => _Chip(label: label, color: color);
}

class LifestyleGrid extends StatelessWidget {
  final UserProfile profile;
  const LifestyleGrid({super.key, required this.profile});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class LifestyleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const LifestyleRow(
      {super.key,
      required this.icon,
      required this.title,
      required this.value});
  @override
  Widget build(BuildContext context) =>
      _LabeledRow(icon: icon, label: title, value: value);
}

