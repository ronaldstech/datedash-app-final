import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/call_service.dart';
import '../providers/language_provider.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerPhoto;
  final String chatId;
  final bool isVideo;
  final String roomName;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerPhoto,
    required this.chatId,
    required this.isVideo,
    required this.roomName,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final CallService _callService = CallService();
  final FlutterRingtonePlayer _ringtonePlayer = FlutterRingtonePlayer();

  @override
  void initState() {
    super.initState();
    _ringtonePlayer.playRingtone();
  }

  @override
  void dispose() {
    _ringtonePlayer.stop();
    super.dispose();
  }

  void _acceptCall() async {
    await _callService.answerCall(widget.chatId);
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

  void _declineCall() async {
    _ringtonePlayer.stop();
    await _callService.endCall(widget.chatId);
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _ringtonePlayer.stop();
                Navigator.pop(context);
              }
            });
            return Scaffold(
              backgroundColor: const Color(0xFF1E1E1E),
              body: Center(
                child: Text(
                  lp.getString('call_cancelled'),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            );
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
                        backgroundColor:
                            const Color(0xFFFF4D85).withValues(alpha: 	0.2),
                        backgroundImage: widget.callerPhoto.isNotEmpty
                            ? NetworkImage(widget.callerPhoto)
                            : null,
                        child: widget.callerPhoto.isEmpty
                            ? const Icon(Icons.person,
                                size: 60, color: Color(0xFFFF4D85))
                            : null,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.callerName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.isVideo
                              ? const Color(0xFFFF4D85).withValues(alpha: 	0.15)
                              : Colors.blueAccent.withValues(alpha: 	0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.isVideo
                                ? const Color(0xFFFF4D85)
                                : Colors.blueAccent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isVideo ? Iconsax.video : Iconsax.call,
                              size: 16,
                              color: widget.isVideo
                                  ? const Color(0xFFFF4D85)
                                  : Colors.blueAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isVideo
                                  ? lp.getString('incoming_video_call')
                                  : lp.getString('incoming_voice_call'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: widget.isVideo
                                    ? const Color(0xFFFF4D85)
                                    : Colors.blueAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Iconsax.call_remove,
                      color: Colors.redAccent,
                      label: lp.getString('decline'),
                      onTap: _declineCall,
                    ),
                    _buildActionButton(
                      icon: widget.isVideo ? Iconsax.video : Iconsax.call,
                      color: Colors.green,
                      label: lp.getString('accept'),
                      onTap: _acceptCall,
                    ),
                  ],
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

