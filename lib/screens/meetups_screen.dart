import 'package:snellum/models/user_profile_model.dart';
import 'package:snellum/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/meetup_model.dart';
import '../services/meetup_service.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import '../theme/theme_provider.dart';
import 'chat_screen.dart';

class MeetupsScreen extends StatelessWidget {
  const MeetupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final myUid = context.read<ProfileProvider>().currentUser?.uid;

    if (myUid == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            languageProvider.getString('my_meetups'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          bottom: TabBar(
            indicatorColor: const Color(0xFFFF4D85),
            labelColor: const Color(0xFFFF4D85),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: languageProvider.getString('received_tab')),
              Tab(text: languageProvider.getString('sent_tab')),
            ],
          ),
        ),
        body: StreamBuilder<List<MeetupModel>>(
          stream: MeetupService().getUserMeetupsStream(myUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF4D85)));
            }

            if (snapshot.hasError) {
              debugPrint('Firestore Error in Meetups: ${snapshot.error}');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error loading meetups: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final meetups = snapshot.data ?? [];

            final received =
                meetups.where((b) => b.receiverId == myUid).toList();
            final sent = meetups.where((b) => b.senderId == myUid).toList();

            return TabBarView(
              children: [
                _buildMeetupList(context, received,
                    isSent: false, myUid: myUid, lp: languageProvider),
                _buildMeetupList(context, sent, isSent: true, myUid: myUid, lp: languageProvider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMeetupList(BuildContext context, List<MeetupModel> meetups,
      {required bool isSent, required String myUid, required LanguageProvider lp}) {
    if (meetups.isEmpty) {
      return _buildEmptyState(
          isSent ? lp.getString('no_sent_requests') : lp.getString('no_received_requests'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meetups.length,
      itemBuilder: (context, index) {
        final meetup = meetups[index];
        return _buildMeetupCard(context, meetup,
            isSent: isSent, myUid: myUid, lp: lp);
      },
    );
  }

  Widget _buildMeetupCard(BuildContext context, MeetupModel meetup,
      {required bool isSent, required String myUid, required LanguageProvider lp}) {
    final theme = Theme.of(context);
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    final name = isSent
        ? (meetup.receiverName ?? 'User')
        : (meetup.senderName ?? 'User');
    final photoUrl = isSent ? meetup.receiverPhoto : meetup.senderPhoto;
    final dateStr = DateFormat('MMM d, y • h:mm a').format(meetup.dateTime);

    Color statusColor;
    IconData statusIcon;
    String statusText = meetup.status.toString().split('.').last.toUpperCase();

    switch (meetup.status) {
      case MeetupStatus.accepted:
        statusColor = const Color(0xFF00C853);
        statusIcon = Iconsax.verify5;
        break;
      case MeetupStatus.rejected:
      case MeetupStatus.cancelled:
        statusColor = const Color(0xFFFF5E5E);
        statusIcon = Iconsax.close_circle5;
        break;
      case MeetupStatus.pending:
        statusColor = const Color(0xFFFFA000);
        statusIcon = Iconsax.clock5;
        break;
    }

    return FutureBuilder<UserProfile?>(
      future: photoUrl == null
          ? ProfileService()
              .getUserProfile(isSent ? meetup.receiverId : meetup.senderId)
          : Future.value(null),
      builder: (context, snapshot) {
        String? finalPhotoUrl = photoUrl;
        if (photoUrl == null &&
            snapshot.hasData &&
            snapshot.data?.photos.isNotEmpty == true) {
          finalPhotoUrl = snapshot.data!.photos.first;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 	isDark ? 0.05 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.withValues(alpha: 	0.2),
                      backgroundImage: finalPhotoUrl != null
                          ? NetworkImage(finalPhotoUrl)
                          : null,
                      child: finalPhotoUrl == null
                          ? const Icon(Iconsax.user,
                              size: 20, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isSent
                            ? lp.getString('to_user').replaceAll('{name}', name)
                            : lp.getString('from_user').replaceAll('{name}', name),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Details
                _detailRow(Iconsax.calendar_2, lp.getString('date_time_label'), dateStr, theme),

                if (meetup.location?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _detailRow(
                      Iconsax.location, lp.getString('location_label'), meetup.location!, theme),
                ],

                if (meetup.rate?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _detailRow(
                      Iconsax.money, lp.getString('rate_req_label'), meetup.rate!, theme),
                ],

                if (meetup.senderNote?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _detailRow(Iconsax.message_text, lp.getString('message_label'),
                      meetup.senderNote!, theme),
                ],

                const SizedBox(height: 20),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        // Navigate to chat
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              otherUserId: isSent
                                  ? meetup.receiverId
                                  : meetup.senderId,
                              otherUserName: name,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Iconsax.messages_2, size: 18),
                      label: Text(lp.getString('chat_btn')),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF4D85),
                      ),
                    ),
                    if (!isSent && meetup.status == MeetupStatus.pending) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _updateStatus(context, meetup.id,
                            MeetupStatus.accepted, meetup.senderId, myUid, lp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(lp.getString('accept_btn'),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _updateStatus(context, meetup.id,
                            MeetupStatus.rejected, meetup.senderId, myUid, lp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5E5E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(lp.getString('decline_btn'),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                    if (isSent && meetup.status == MeetupStatus.pending) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _updateStatus(context, meetup.id,
                            MeetupStatus.cancelled, meetup.receiverId, myUid, lp),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.grey),
                        child: Text(lp.getString('cancel_request_btn')),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
      IconData icon, String label, String value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D85).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.calendar_remove,
                size: 64, color: Color(0xFFFF4D85)),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _updateStatus(BuildContext context, String meetupId,
      MeetupStatus status, String otherUserId, String myUid, LanguageProvider lp) async {
    try {
      final myName = context.read<ProfileProvider>().displayName;
      await MeetupService().updateMeetupStatus(
        meetupId,
        status,
        currentUserId: myUid,
        otherUserId: otherUserId,
        senderName: myName,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lp
                  .getString('meetup_status_updated')
                  .replaceAll('{status}', status.toString().split('.').last),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lp.getString('error_updating_status').replaceAll('{e}', e.toString()),
            ),
          ),
        );
      }
    }
  }
}
