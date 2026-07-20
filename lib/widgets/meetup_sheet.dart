import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/meetup_model.dart';
import '../models/user_profile_model.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';
import '../services/meetup_service.dart';
import '../utils/date_formatter.dart';
import '../providers/profile_provider.dart';

class MeetupSheet extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String chatId;
  final String myUid;

  const MeetupSheet({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.chatId,
    required this.myUid,
  });

  @override
  State<MeetupSheet> createState() => _MeetupSheetState();
}

class _MeetupSheetState extends State<MeetupSheet> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  final TextEditingController _senderNoteController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingProfile = true;
  UserProfile? _recipientProfile;
  bool _hasPendingRequest = false;

  @override
  void initState() {
    super.initState();
    _loadRecipientProfile();
  }

  @override
  void dispose() {
    _senderNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipientProfile() async {
    final profile = await ProfileService().getUserProfile(widget.otherUserId);
    final pendingMeetup = await MeetupService().getPendingMeetup(widget.myUid, widget.otherUserId);
    if (mounted) {
      setState(() {
        _recipientProfile = profile;
        _hasPendingRequest = pendingMeetup != null;
        _isLoadingProfile = false;
      });
    }
  }

  bool get _hasMeetupPrefs =>
      (_recipientProfile?.meetupLocation?.isNotEmpty ?? false) ||
      (_recipientProfile?.meetupRate?.isNotEmpty ?? false) ||
      (_recipientProfile?.meetupNotes?.isNotEmpty ?? false);

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF4D85),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF4D85),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _confirmAndSubmit() async {
    if (_isSubmitting) return;

    final profileProvider = context.read<ProfileProvider>();
    final userProfile = profileProvider.userProfile;
    if (userProfile == null) return;

    if (userProfile.credits < 100) {
      _showInsufficientCreditsDialog();
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Meetup Request',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'Sending a meetup request costs 100 credits. Do you want to proceed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D85),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send (100 Credits)'),
          ),
        ],
      ),
    );

    if (confirm == true) _submitMeetup();
  }

  void _showInsufficientCreditsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Insufficient Credits'),
        content: const Text('You need 100 credits to send a meetup request.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _submitMeetup() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final profileProvider = context.read<ProfileProvider>();
    final myProfile = profileProvider.userProfile;

    // Check if the reason/senderNote is repeated from other requests
    final trimmedNote = _senderNoteController.text.trim();
    if (trimmedNote.isNotEmpty) {
      try {
        final existingMeetups = await FirebaseFirestore.instance
            .collection('meetups')
            .where('senderId', isEqualTo: widget.myUid)
            .where('senderNote', isEqualTo: trimmedNote)
            .get();

        if (existingMeetups.docs.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please write a unique personal message. Do not repeat messages from previous requests.'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() => _isSubmitting = false);
          }
          return;
        }
      } catch (e) {
        debugPrint('Error validating unique reason: $e');
      }
    }

    final finalDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      await profileProvider.useCredits(100);

      final docRef = FirebaseFirestore.instance.collection('meetups').doc();
      final meetup = MeetupModel(
        id: docRef.id,
        senderId: widget.myUid,
        receiverId: widget.otherUserId,
        senderName: myProfile?.firstName ?? 'Someone',
        receiverName: widget.otherUserName,
        senderPhoto: myProfile?.photos.isNotEmpty == true ? myProfile!.photos.first : null,
        receiverPhoto: _recipientProfile?.photos.isNotEmpty == true ? _recipientProfile!.photos.first : null,
        dateTime: finalDateTime,
        location: _recipientProfile?.meetupLocation,
        rate: _recipientProfile?.meetupRate,
        note: _recipientProfile?.meetupNotes,
        senderNote: _senderNoteController.text.trim().isNotEmpty
            ? _senderNoteController.text.trim()
            : null,
        timestamp: DateTime.now(),
      );

      await docRef.set(meetup.toMap());

      final dateStr = DateFormatter.formatMeetupDateTime(finalDateTime);
      await ChatService().sendMeetupMessage(
        chatId: widget.chatId,
        senderId: widget.myUid,
        receiverId: widget.otherUserId,
        meetupId: docRef.id,
        text: 'I\'d like to meet on $dateStr',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meetup request sent! 🎉'),
            backgroundColor: Color(0xFFFF4D85),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: _isLoadingProfile
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF4D85))),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 	0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    children: [
                      const Icon(Iconsax.calendar_add,
                          color: Color(0xFFFF4D85), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Meet ${widget.otherUserName}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Recipient's meetup preferences card ───────────
                  if (_hasMeetupPrefs) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4D85).withValues(alpha: 	0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFFF4D85).withValues(alpha: 	0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Iconsax.info_circle,
                                  color: Color(0xFFFF4D85), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.otherUserName}\'s Meetup Info',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFF4D85),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (_recipientProfile?.meetupLocation?.isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 10),
                            _prefRow(Iconsax.location,
                                _recipientProfile!.meetupLocation!),
                          ],
                          if (_recipientProfile?.meetupRate?.isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 6),
                            _prefRow(Iconsax.money,
                                _recipientProfile!.meetupRate!),
                          ],
                          if (_recipientProfile?.meetupNotes?.isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 6),
                            _prefRow(Iconsax.note_text,
                                _recipientProfile!.meetupNotes!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Pending request info card ─────────────────────
                  if (_hasPendingRequest) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 	0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withValues(alpha: 	0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.info_circle, color: Colors.amber, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'A meetup request is currently pending with ${widget.otherUserName}. You can manage all meetup requests under My Meetups.',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 	0.8),
                                  height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Date & Time ────────────────────────────────────
                  _buildSelectionRow(
                    icon: Iconsax.calendar,
                    label: 'Date',
                    value:
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    onTap: _hasPendingRequest ? () {} : _selectDate,
                  ),
                  const SizedBox(height: 12),
                  _buildSelectionRow(
                    icon: Iconsax.clock,
                    label: 'Time',
                    value: _selectedTime.format(context),
                    onTap: _hasPendingRequest ? () {} : _selectTime,
                  ),
                  const SizedBox(height: 16),

                  // ── Personal note from sender ──────────────────────
                  TextField(
                    controller: _senderNoteController,
                    enabled: !_hasPendingRequest,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: _hasPendingRequest
                          ? 'Message input disabled (pending request)'
                          : 'Add a personal message (optional)...',
                      prefixIcon: const Icon(Iconsax.message_edit),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Send button ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isSubmitting || _hasPendingRequest) ? null : _confirmAndSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D85),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _hasPendingRequest ? 'Pending Request Sent' : 'Send Meetup Request',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _prefRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFFF4D85),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
