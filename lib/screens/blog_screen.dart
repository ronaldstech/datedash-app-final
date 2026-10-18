import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/blog_post_model.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/blog_service.dart';

const _blogPink = Color(0xFFFF4D85);
const _blogViolet = Color(0xFF8A5CF6);
const _blogTopics = [
  'Dating Advice',
  'Relationships',
  'Personal Story',
  'Self Growth',
];

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  final BlogService _blogService = BlogService();
  late Stream<List<BlogPost>> _posts;
  int _streamVersion = 0;

  @override
  void initState() {
    super.initState();
    _posts = _blogService.watchPublishedPosts();
  }

  void _refresh() {
    setState(() {
      _streamVersion++;
      _posts = _blogService.watchPublishedPosts();
    });
  }

  Future<void> _openComposer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to publish a story.')),
      );
      return;
    }

    final published = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const BlogComposerScreen()));
    if (!mounted) return;
    if (published == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your story is now published.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          language.getString('blog_page_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        backgroundColor: _blogPink,
        foregroundColor: Colors.white,
        icon: const Icon(Iconsax.edit_2),
        label: Text(language.getString('blog_write')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
            child: _BlogHero(
              title: language.getString('blog_page_subtitle'),
              publicLabel: language.getString('blog_public_badge'),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<BlogPost>>(
              key: ValueKey(_streamVersion),
              stream: _posts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _blogPink),
                  );
                }
                if (snapshot.hasError) {
                  return _BlogMessageState(
                    icon: Iconsax.cloud_cross,
                    title: 'Stories could not load',
                    message:
                        'Check your connection and try loading the community stories again.',
                    actionLabel: 'Try again',
                    onAction: _refresh,
                  );
                }

                final posts = snapshot.data ?? const <BlogPost>[];
                if (posts.isEmpty) {
                  return _BlogMessageState(
                    icon: Iconsax.book_1,
                    title: language.getString('blog_empty_title'),
                    message: language.getString('blog_empty_subtitle'),
                    actionLabel: language.getString('blog_start_writing'),
                    onAction: _openComposer,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 104),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _BlogPostCard(
                    post: posts[index],
                    isDark: isDark,
                    readLabel: language.getString('blog_read'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlogDetailScreen(post: posts[index]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BlogHero extends StatelessWidget {
  final String title;
  final String publicLabel;

  const _BlogHero({required this.title, required this.publicLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_blogPink, _blogViolet],
        ),
        boxShadow: [
          BoxShadow(
            color: _blogPink.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.17),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    publicLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.book_saved,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlogPostCard extends StatelessWidget {
  final BlogPost post;
  final bool isDark;
  final String readLabel;
  final VoidCallback onTap;

  const _BlogPostCard({
    required this.post,
    required this.isDark,
    required this.readLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.58);

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.035),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TopicBadge(label: post.category),
                  const Spacer(),
                  Icon(Iconsax.clock, size: 14, color: muted),
                  const SizedBox(width: 5),
                  Text(
                    '${post.estimatedReadMinutes} $readLabel',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.25,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                post.body.replaceAll(RegExp(r'\s+'), ' ').trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, height: 1.45, color: muted),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  _AuthorAvatar(url: post.authorPhotoUrl, radius: 16),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _publishedDate(post.publishedAt),
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Iconsax.arrow_right_3, color: muted, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicBadge extends StatelessWidget {
  final String label;

  const _TopicBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _blogPink.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _blogPink,
          fontSize: 9,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  final String? url;
  final double radius;

  const _AuthorAvatar({required this.url, required this.radius});

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: _blogPink.withValues(alpha: 0.12),
      child: imageUrl.isEmpty
          ? Icon(Iconsax.user, size: radius, color: _blogPink)
          : ClipOval(
              child: Image.network(
                imageUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(Iconsax.user, size: radius, color: _blogPink),
              ),
            ),
    );
  }
}

class _BlogMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _BlogMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(30, 20, 30, 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 78,
              width: 78,
              decoration: BoxDecoration(
                color: _blogPink.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: _blogPink),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: _blogPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
              ),
              icon: const Icon(Iconsax.edit_2, size: 17),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class BlogComposerScreen extends StatefulWidget {
  const BlogComposerScreen({super.key});

  @override
  State<BlogComposerScreen> createState() => _BlogComposerScreenState();
}

class _BlogComposerScreenState extends State<BlogComposerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _blogService = BlogService();
  String _category = _blogTopics.first;
  bool _publishing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to publish a story.')),
      );
      return;
    }

    setState(() => _publishing = true);
    try {
      final profileProvider = context.read<ProfileProvider>();
      final profile = profileProvider.userProfile;
      final authorName = profile?.firstName?.trim().isNotEmpty == true
          ? profile!.firstName!.trim()
          : user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'Snellum member';

      await _blogService.publishPost(
        authorId: user.uid,
        authorName: authorName,
        authorPhotoUrl: profileProvider.photoURL,
        title: _titleController.text,
        body: _bodyController.text,
        category: _category,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish your story: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          language.getString('blog_composer_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _blogPink.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: _blogPink.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.global, color: _blogPink, size: 21),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      language.getString('blog_published_notice'),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _FieldLabel(text: language.getString('blog_title_label')),
            const SizedBox(height: 9),
            TextFormField(
              controller: _titleController,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                context,
                hint: language.getString('blog_title_hint'),
              ),
              validator: (value) {
                final length = value?.trim().length ?? 0;
                return length < 5 || length > 120
                    ? language.getString('blog_title_validation')
                    : null;
              },
            ),
            const SizedBox(height: 12),
            _FieldLabel(text: language.getString('blog_topic_label')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _blogTopics.map((topic) {
                final selected = _category == topic;
                return ChoiceChip(
                  label: Text(topic),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: _publishing
                      ? null
                      : (_) => setState(() => _category = topic),
                  selectedColor: _blogPink.withValues(alpha: 0.14),
                  side: BorderSide(
                    color: selected
                        ? _blogPink.withValues(alpha: 0.55)
                        : Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  ),
                  labelStyle: TextStyle(
                    color: selected ? _blogPink : null,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            _FieldLabel(text: language.getString('blog_body_label')),
            const SizedBox(height: 9),
            TextFormField(
              controller: _bodyController,
              minLines: 9,
              maxLines: 16,
              maxLength: 12000,
              textCapitalization: TextCapitalization.sentences,
              textAlignVertical: TextAlignVertical.top,
              decoration: _inputDecoration(
                context,
                hint: language.getString('blog_body_hint'),
              ).copyWith(alignLabelWithHint: true),
              validator: (value) {
                final length = value?.trim().length ?? 0;
                return length < 30
                    ? language.getString('blog_body_validation')
                    : null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _publishing ? null : _publish,
                style: FilledButton.styleFrom(
                  backgroundColor: _blogPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                icon: _publishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Iconsax.send_2, size: 18),
                label: Text(
                  language.getString(
                    _publishing ? 'blog_publishing' : 'blog_publish',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
  );
}

InputDecoration _inputDecoration(BuildContext context, {required String hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Theme.of(context).cardColor,
    hintStyle: TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      fontWeight: FontWeight.w400,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: BorderSide(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.22),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: BorderSide(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.22),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: _blogPink, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
  );
}

class BlogDetailScreen extends StatelessWidget {
  final BlogPost post;

  const BlogDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _TopicBadge(label: post.category),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.category.toUpperCase(),
              style: const TextStyle(
                color: _blogPink,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 30,
                height: 1.12,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _AuthorAvatar(url: post.authorPhotoUrl, radius: 22),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${language.getString('blog_detail_author')}  ·  ${_publishedDate(post.publishedAt)}',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              height: 4,
              width: 48,
              decoration: BoxDecoration(
                color: _blogPink,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 24),
            SelectableText(
              post.body,
              style: TextStyle(fontSize: 16, height: 1.75, color: muted),
            ),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: _blogPink.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.heart, color: _blogPink),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'Good connections start with good conversations.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _publishedDate(DateTime? date) {
  if (date == null) return 'Recently';
  return DateFormat.yMMMd().format(date.toLocal());
}
