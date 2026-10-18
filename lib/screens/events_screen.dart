import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_profile_model.dart';
import '../providers/profile_provider.dart';

const _eventPink = Color(0xFFFF4D85);
const _eventAmber = Color(0xFFFFA726);

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String _selectedCity = 'All';
  int _streamVersion = 0;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _events;

  @override
  void initState() {
    super.initState();
    _events = FirebaseFirestore.instance.collection('events').snapshots();
  }

  void _reloadEvents() {
    setState(() {
      _streamVersion++;
      _events = FirebaseFirestore.instance.collection('events').snapshots();
    });
  }

  DateTime? _eventDate(Map<String, dynamic> event) {
    final value = event['date'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  bool _isFree(Map<String, dynamic> event) {
    if (event['isFree'] == true) return true;
    final price = event['price'];
    if (price == null) return true;
    final text = price.toString().trim().toLowerCase();
    return text.isEmpty || text == 'free' || text == '0' || text == '0.0';
  }

  String _priceLabel(Map<String, dynamic> event) {
    if (_isFree(event)) return 'Free';
    final price = event['price']?.toString().trim();
    if (price != null && price.isNotEmpty) return price;
    final cents = event['cents'];
    if (cents is num) return '\$${(cents / 100).toStringAsFixed(2)}';
    return 'Ticket required';
  }

  List<Map<String, dynamic>> _publishedEvents(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final events = snapshot.docs
        .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
        .where((event) => (event['status'] ?? 'published') == 'published')
        .toList();
    events.sort((a, b) {
      final aDate = _eventDate(a);
      final bDate = _eventDate(b);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().userProfile;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Events',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        key: ValueKey(_streamVersion),
        stream: _events,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _EventsErrorState(onRetry: _reloadEvents);
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _eventPink),
            );
          }

          final events = _publishedEvents(snapshot.data!);
          final cityNames =
              events
                  .map((event) => event['city']?.toString().trim() ?? '')
                  .where((city) => city.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          final cities = ['All', ...cityNames];
          final selectedCity = cities.contains(_selectedCity)
              ? _selectedCity
              : 'All';
          final visibleEvents = selectedCity == 'All'
              ? events
              : events.where((event) {
                  return (event['city']?.toString() ?? '').toLowerCase() ==
                      selectedCity.toLowerCase();
                }).toList();

          return RefreshIndicator(
            color: _eventPink,
            onRefresh: () async => _reloadEvents(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              children: [
                _EventsHero(eventCount: events.length),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Find your next plan',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _eventPink.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${visibleEvents.length} ${visibleEvents.length == 1 ? 'event' : 'events'}',
                        style: const TextStyle(
                          color: _eventPink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (cityNames.isNotEmpty)
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: cities.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final city = cities[index];
                        final isSelected = city == selectedCity;
                        return ChoiceChip(
                          avatar: Icon(
                            index == 0
                                ? Icons.explore_outlined
                                : Icons.location_on_outlined,
                            size: 15,
                            color: isSelected ? Colors.white : _eventPink,
                          ),
                          label: Text(city),
                          selected: isSelected,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => _selectedCity = city),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          selectedColor: _eventPink,
                          backgroundColor: Theme.of(context).cardColor,
                          side: BorderSide(
                            color: isSelected
                                ? _eventPink
                                : Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.25),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 18),
                if (visibleEvents.isEmpty)
                  _EventsEmptyState(city: selectedCity)
                else
                  ...visibleEvents.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _EventCard(
                        event: event,
                        isFree: _isFree(event),
                        priceLabel: _priceLabel(event),
                        date: _eventDate(event),
                        onTap: () => _showEventDetails(context, event, profile),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEventDetails(
    BuildContext context,
    Map<String, dynamic> event,
    UserProfile? profile,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventDetailsSheet(
        event: event,
        profile: profile,
        isFree: _isFree(event),
        priceLabel: _priceLabel(event),
        date: _eventDate(event),
      ),
    );
  }
}

class _EventsHero extends StatelessWidget {
  const _EventsHero({required this.eventCount});

  final int eventCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4D85), Color(0xFFFF8C65), Color(0xFFFFB454)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _eventPink.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -12,
            child: Icon(
              Icons.auto_awesome,
              size: 112,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.19),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'MEET IN REAL LIFE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Good people.\nGreat plans.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Find a reason to get out, meet someone new, and make a story worth telling.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.91),
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(
                    Icons.event_available,
                    color: Colors.white,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '$eventCount ${eventCount == 1 ? 'upcoming event' : 'upcoming events'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.isFree,
    required this.priceLabel,
    required this.date,
    required this.onTap,
  });

  final Map<String, dynamic> event;
  final bool isFree;
  final String priceLabel;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = event['title']?.toString().trim().isNotEmpty == true
        ? event['title'].toString()
        : 'Snellum community event';
    final imageUrl = event['image']?.toString() ?? '';
    final city = event['city']?.toString() ?? 'Location to be announced';
    final venue = event['venue']?.toString() ?? '';
    final category = event['category']?.toString() ?? 'Community event';
    final description =
        event['subtitle']?.toString() ??
        event['description']?.toString() ??
        'Meet new people and enjoy a great time with the Snellum community.';

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.light ? 0.035 : 0.12,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 190,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _EventImage(url: imageUrl),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black26,
                            Colors.transparent,
                            Colors.black45,
                          ],
                          stops: [0, 0.46, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 14,
                      child: _GlassPill(
                        icon: Icons.auto_awesome,
                        label: category,
                      ),
                    ),
                    Positioned(
                      right: 14,
                      top: 14,
                      child: _DateBadge(date: date),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.72,
                        ),
                        height: 1.4,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: _eventPink,
                          size: 17,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            venue.isEmpty ? city : '$city · $venue',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.18),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          size: 18,
                          color: isFree ? const Color(0xFF159B67) : _eventAmber,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          priceLabel,
                          style: TextStyle(
                            color: isFree
                                ? const Color(0xFF159B67)
                                : _eventAmber,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Details',
                          style: TextStyle(
                            color: _eventPink,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: _eventPink,
                          size: 16,
                        ),
                      ],
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
}

class _EventImage extends StatelessWidget {
  const _EventImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFFFFE7EF),
      alignment: Alignment.center,
      child: const Icon(Icons.auto_awesome, size: 42, color: _eventPink),
    );
    if (url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFFFE7EF),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(strokeWidth: 2, color: _eventPink),
          ),
        );
      },
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 145),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final day = date == null ? '—' : DateFormat('dd').format(date!);
    final month = date == null
        ? 'DATE TBA'
        : DateFormat('MMM').format(date!).toUpperCase();
    return Container(
      width: 54,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: const TextStyle(
              fontSize: 20,
              height: 1,
              fontWeight: FontWeight.w900,
              color: Color(0xFF21151B),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            month,
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w900,
              color: _eventPink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsEmptyState extends StatelessWidget {
  const _EventsEmptyState({required this.city});
  final String city;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 30),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: _eventPink.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_outlined,
              color: _eventPink,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            city == 'All'
                ? 'Nothing on the calendar yet'
                : 'No events in $city yet',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 7),
          Text(
            'New Snellum gatherings are on the way. Check back soon for your next great plan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).hintColor,
              height: 1.45,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsErrorState extends StatelessWidget {
  const _EventsErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _eventPink, size: 42),
            const SizedBox(height: 14),
            const Text(
              'Events are taking a break',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              'We could not load the event list. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _eventPink),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDetailsSheet extends StatefulWidget {
  const _EventDetailsSheet({
    required this.event,
    required this.profile,
    required this.isFree,
    required this.priceLabel,
    required this.date,
  });

  final Map<String, dynamic> event;
  final UserProfile? profile;
  final bool isFree;
  final String priceLabel;
  final DateTime? date;

  @override
  State<_EventDetailsSheet> createState() => _EventDetailsSheetState();
}

class _EventDetailsSheetState extends State<_EventDetailsSheet> {
  bool _isSubmitting = false;
  bool _applicationSent = false;

  String get _eventId => widget.event['id']?.toString() ?? '';
  String get _eventTitle =>
      widget.event['title']?.toString() ?? 'Snellum event';
  String get _shareUrl =>
      'https://snellum.web.app/?event=${Uri.encodeQueryComponent(widget.event['slug']?.toString() ?? _eventId)}';

  @override
  void initState() {
    super.initState();
    _checkApplication();
  }

  Future<void> _checkApplication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _eventId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('eventApplications')
          .doc('${_eventId}_${user.uid}')
          .get();
      if (mounted && doc.exists) setState(() => _applicationSent = true);
    } catch (_) {
      // The user can still submit; Firestore will report any write failure.
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF21151B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _submitFreeApplication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Please sign in to apply for this event.', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final name = widget.profile?.firstName?.trim().isNotEmpty == true
          ? widget.profile!.firstName!.trim()
          : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : 'Snellum Member');
      await FirebaseFirestore.instance
          .collection('eventApplications')
          .doc('${_eventId}_${user.uid}')
          .set({
            'eventId': _eventId,
            'eventTitle': _eventTitle,
            'userId': user.uid,
            'name': name,
            'email': user.email ?? '',
            'status': 'pending',
            'createdAt': DateTime.now().toIso8601String(),
          });
      if (!mounted) return;
      setState(() => _applicationSent = true);
      _showMessage('Your application for $_eventTitle was sent.');
    } catch (error) {
      _showMessage(
        'Could not send your application. Please try again.',
        isError: true,
      );
      debugPrint('Free event RSVP failed: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _shareEvent() async {
    final text =
        'Join me at $_eventTitle in ${widget.event['city'] ?? 'Malawi'}! $_shareUrl';
    final uri = Uri.https('wa.me', '/', {'text': text});
    if (await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _shareUrl));
    _showMessage('Event link copied to clipboard.');
  }

  Future<void> _addToCalendar() async {
    final date = widget.date;
    if (date == null) {
      _showMessage('The event date has not been announced yet.', isError: true);
      return;
    }
    final start = date.toUtc();
    final end = start.add(const Duration(hours: 3));
    final format = DateFormat("yyyyMMdd'T'HHmmss'Z'");
    final dates = '${format.format(start)}/${format.format(end)}';
    final venue = widget.event['venue']?.toString() ?? '';
    final city = widget.event['city']?.toString() ?? '';
    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': _eventTitle,
      'dates': dates,
      'details':
          widget.event['description']?.toString() ??
          widget.event['subtitle']?.toString() ??
          'A Snellum community event.',
      'location': [
        venue,
        city,
        'Malawi',
      ].where((part) => part.isNotEmpty).join(', '),
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('Could not open your calendar.', isError: true);
    }
  }

  Future<void> _openPaidTicketPage() async {
    final uri = Uri.parse(_shareUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('Could not open the event ticket page.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = widget.event['image']?.toString() ?? '';
    final city = widget.event['city']?.toString() ?? 'Location to be announced';
    final venue = widget.event['venue']?.toString() ?? 'Venue to be announced';
    final subtitle = widget.event['subtitle']?.toString();
    final description = widget.event['description']?.toString();
    final organizer = widget.event['organizer']?.toString() ?? 'Snellum Events';
    final highlights = widget.event['highlights'];
    final spotsLeft = widget.event['spotsLeft'];
    final capacity = widget.event['capacity'];
    final date = widget.date;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 244,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _EventImage(url: imageUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black38,
                        Colors.transparent,
                        Colors.black87,
                      ],
                      stops: [0, 0.4, 1],
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 14,
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 19,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GlassPill(
                        icon: Icons.auto_awesome,
                        label:
                            widget.event['category']?.toString() ??
                            'Community event',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _eventTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _EventInfoTile(
                        icon: Icons.calendar_month_outlined,
                        iconColor: _eventPink,
                        title: date == null
                            ? 'Date to be announced'
                            : DateFormat('EEE, MMM d, yyyy').format(date),
                        subtitle: date == null
                            ? 'Check back for updates'
                            : DateFormat.jm().format(date),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                _EventInfoTile(
                  icon: Icons.location_on_outlined,
                  iconColor: _eventAmber,
                  title: venue,
                  subtitle: '$city, Malawi',
                ),
                if (spotsLeft != null || capacity != null) ...[
                  const SizedBox(height: 11),
                  _EventInfoTile(
                    icon: Icons.people_outline_rounded,
                    iconColor: const Color(0xFF159B67),
                    title: spotsLeft != null
                        ? '$spotsLeft spots remaining'
                        : '$capacity places',
                    subtitle: 'Event availability',
                  ),
                ],
                const SizedBox(height: 11),
                _EventInfoTile(
                  icon: Icons.confirmation_number_outlined,
                  iconColor: widget.isFree
                      ? const Color(0xFF159B67)
                      : _eventAmber,
                  title: widget.priceLabel,
                  subtitle: 'Entry price',
                ),
                const SizedBox(height: 21),
                Text(
                  'About this event',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (description?.trim().isNotEmpty == true
                                  ? description
                                  : subtitle)
                              ?.trim()
                              .isNotEmpty ==
                          true
                      ? (description?.trim().isNotEmpty == true
                            ? description!
                            : subtitle!)
                      : 'Join the Snellum community for a fun opportunity to meet new people and enjoy a memorable experience.',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.78,
                    ),
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
                if (highlights is List && highlights.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Highlights',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  ...highlights.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF159B67),
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 17),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: _eventPink,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hosted by $organizer',
                        style: TextStyle(
                          color: theme.hintColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.event['dressCode']?.toString().trim().isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.checkroom_outlined,
                        color: _eventPink,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Dress code: ${widget.event['dressCode']}',
                        style: TextStyle(color: theme.hintColor, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(18, 12, 18, 12 + bottomInset),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.18),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Share event',
                  onPressed: _shareEvent,
                  icon: const Icon(Icons.ios_share_rounded, size: 19),
                  color: _eventPink,
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Add to calendar',
                  onPressed: _addToCalendar,
                  icon: const Icon(Icons.calendar_month_outlined, size: 19),
                  color: _eventPink,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting || _applicationSent
                          ? null
                          : widget.isFree
                          ? _submitFreeApplication
                          : _openPaidTicketPage,
                      style: FilledButton.styleFrom(
                        backgroundColor: _eventPink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF159B67),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _applicationSent
                                  ? Icons.check_circle_outline
                                  : widget.isFree
                                  ? Icons.send_rounded
                                  : Icons.confirmation_number_outlined,
                              size: 18,
                            ),
                      label: Text(
                        _applicationSent
                            ? 'Application sent'
                            : _isSubmitting
                            ? 'Sending…'
                            : widget.isFree
                            ? 'Apply for free'
                            : 'Get tickets',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventInfoTile extends StatelessWidget {
  const _EventInfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
