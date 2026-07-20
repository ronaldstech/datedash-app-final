import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import '../services/call_service.dart';
import '../services/notification_service.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverPhoto;
  final String chatId;
  final bool isVideo;
  final String roomName;

  const OutgoingCallScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhoto,
    required this.chatId,
    required this.isVideo,
    required this.roomName,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  final CallService _callService = CallService();
  final FlutterRingtonePlayer _ringtonePlayer = FlutterRingtonePlayer();
  Timer? _timeoutTimer;
  bool _joined = false;
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 30), _handleTimeout);
  }

  void _handleTimeout() async {
    if (!_joined && !_isPopping) {
      debugPrint('Call timeout: No answer after 30s');

      await _callService.endCall(widget.chatId);

      if (mounted) {
        final profileProvider = context.read<ProfileProvider>();
        await NotificationService().sendNotification(
          recipientId: widget.receiverId,
          senderId: profileProvider.currentUser?.uid ?? '',
          senderName: profileProvider.displayName,
          type: 'missed_call',
        );

        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _ringtonePlayer.stop();
    super.dispose();
  }

  void _endCall() async {
    _timeoutTimer?.cancel();
    _ringtonePlayer.stop();
    await _callService.endCall(widget.chatId);
    if (mounted) Navigator.pop(context);
  }

  void _launchJitsiInBrowser() async {
    if (_joined) return;
    _joined = true;
    _timeoutTimer?.cancel();
    _ringtonePlayer.stop();

    const serverBase = "https://meet.ffmuc.net";
    final roomUrl = "$serverBase/${widget.roomName}";
    final uri = Uri.parse(roomUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching Jitsi in browser: $e');
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LanguageProvider>();
    return StreamBuilder<DocumentSnapshot>(
      stream: _callService.listenToCallState(widget.chatId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final doc = snapshot.data;

          if (doc == null || !doc.exists) {
            if (!_isPopping) {
              _isPopping = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.pop(context);
              });
            }
            return Scaffold(
              backgroundColor: const Color(0xFF1E1E1E),
              body: Center(
                child: Text(lp.getString('call_ended'), style: const TextStyle(color: Colors.white)),
              ),
            );
          }

          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?;

          if (status == 'answered') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _launchJitsiInBrowser();
            });
          }
        }

        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: const Color(0xFFFF4D85).withValues(alpha: 	0.2),
                        backgroundImage: widget.receiverPhoto.isNotEmpty
                            ? NetworkImage(widget.receiverPhoto)
                            : null,
                        child: widget.receiverPhoto.isEmpty
                            ? const Icon(Icons.person, size: 60, color: Color(0xFFFF4D85))
                            : null,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.receiverName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isVideo ? lp.getString('dialing_video_call') : lp.getString('dialing_voice_call'),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _buildActionButton(
                  icon: Iconsax.call_remove,
                  color: Colors.redAccent,
                  label: lp.getString('cancel'),
                  onTap: _endCall,
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 	0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

