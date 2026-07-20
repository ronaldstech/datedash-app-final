import 'package:datedash/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../widgets/bordered_search_bar.dart';

import '../services/profile_service.dart';
import '../providers/language_provider.dart';

import '../widgets/swipe_view.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final profileProvider = context.watch<ProfileProvider>();

    // If a category is selected, show the SwipeView instead of the grid
    if (profileProvider.selectedExploreCategory != null) {
      return SwipeView(category: profileProvider.selectedExploreCategory);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              languageProvider.getString('explore_header'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            centerTitle: false,
            floating: true,
            snap: true,
            actions: const [
              BorderedSearchBar(),
              SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Text(
                languageProvider.getString('looking_for_header'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          _buildCategoryGrid(context, languageProvider),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(
      BuildContext context, LanguageProvider languageProvider) {
    final profileProvider = context.read<ProfileProvider>();
    final ProfileService profileService = ProfileService();

    // Keys match EXACTLY what edit_profile_screen.dart writes to Firestore
    final categories = [
      {
        'title': languageProvider.getString('cat_marriage'),
        'subtitle': languageProvider.getString('cat_marriage_sub'),
        'key': 'Marriage',
        'icon': Iconsax.heart_add,
        'photo':
            'https://images.unsplash.com/photo-1515934751635-c81c6bc9a2d8?w=600&q=80',
        'accent': const Color(0xFFD4AF37), // Gold accent for marriage
      },
      {
        'title': languageProvider.getString('cat_long_term'),
        'subtitle': languageProvider.getString('cat_long_term_sub'),
        'key': 'Long Term Relationship',
        'icon': Iconsax.heart5,
        'photo':
            'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=600&q=80',
        'accent': const Color(0xFFFF4D85),
      },
      {
        'title': languageProvider.getString('cat_short_term_rel'),
        'subtitle': languageProvider.getString('cat_short_term_rel_sub'),
        'key': 'Short Term Relationship',
        'icon': Iconsax.calendar_1,
        'photo':
            'https://images.unsplash.com/photo-1511367461989-f85a21fda167?w=600&q=80',
        'accent': const Color(0xFFFF9A8B),
      },
      {
        'title': languageProvider.getString('cat_hookups'),
        'subtitle': languageProvider.getString('cat_hookups_sub'),
        'key': 'Hookups',
        'icon': Iconsax.flash,
        'photo':
            'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=600&q=80',
        'accent': const Color(0xFF8E2DE2),
      },
      {
        'title': languageProvider.getString('cat_short_term'),
        'subtitle': languageProvider.getString('cat_short_term_sub'),
        'key': 'Short Term Fun',
        'icon': Iconsax.emoji_happy,
        'photo':
            'https://images.unsplash.com/photo-1536697246787-1f7ae568d89a?w=600&q=80',
        'accent': const Color(0xFFF2994A),
      },
      {
        'title': languageProvider.getString('cat_new_friends'),
        'subtitle': languageProvider.getString('cat_new_friends_sub'),
        'key': 'New Friends',
        'icon': Iconsax.user_add,
        'photo':
            'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=600&q=80',
        'accent': const Color(0xFF56CCF2),
      },
      {
        'title': languageProvider.getString('cat_coffee_date'),
        'subtitle': languageProvider.getString('cat_coffee_date_sub'),
        'key': 'Coffee Date',
        'icon': Iconsax.cup,
        'photo':
            'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600&q=80',
        'accent': const Color(0xFF7B4F2E),
      },
      {
        'title': languageProvider.getString('cat_movie_night'),
        'subtitle': languageProvider.getString('cat_movie_night_sub'),
        'key': 'Movie Night',
        'icon': Iconsax.video_play4,
        'photo':
            'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=600&q=80',
        'accent': const Color(0xFFEB5757),
      },
      {
        'title': languageProvider.getString('cat_sponsor'),
        'subtitle': languageProvider.getString('cat_sponsor_sub'),
        'key': 'Sponsor',
        'icon': Iconsax.money_2,
        'photo':
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600&q=80',
        'accent': const Color(0xFFDAA520),
      },
      {
        'title': languageProvider.getString('cat_figuring_out'),
        'subtitle': languageProvider.getString('cat_figuring_out_sub'),
        'key': 'Figuring Out',
        'icon': Iconsax.message_question,
        'photo':
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=600&q=80',
        'accent': const Color(0xFF607D8B),
      },
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.78,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final cat = categories[index];
            final accent = cat['accent'] as Color;
            final photo = cat['photo'] as String;

            return GestureDetector(
              onTap: () {
                profileProvider.setExploreCategory(cat['key'] as String);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── Photo background
                    Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: accent),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(color: accent.withValues(alpha: 	0.6));
                      },
                    ),

                    // ── Dark gradient overlay (bottom-heavy for text legibility)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 	0.35),
                            Colors.black.withValues(alpha: 	0.82),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),

                    // ── Content
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon badge
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 	0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 	0.15),
                                  width: 0.5),
                            ),
                            child: Icon(
                              cat['icon'] as IconData,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),

                          const Spacer(),

                          // Title
                          Text(
                            cat['title'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),

                          // Subtitle
                          Text(
                            cat['subtitle'] as String,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 	0.72),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // People count pill
                          StreamBuilder<int>(
                            stream: profileService
                                .getCategoryCountStream(cat['key'] as String),
                            builder: (context, countSnapshot) {
                              final count = countSnapshot.data ?? 0;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 	0.75),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count ${languageProvider.getString('people_count_suffix')}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: categories.length,
        ),
      ),
    );
  }
}

