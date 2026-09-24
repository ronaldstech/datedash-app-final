import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../services/chat_service.dart';
import '../../providers/language_provider.dart';
import '../../screens/outgoing_call_screen.dart';

class CallSheet extends StatelessWidget {
  final String name;
  final String? photo;
  final bool isVideo;
  final String chatId;
  final ChatService chatService;
  final String senderId;
  final String receiverId;

  const CallSheet({
    super.key,
    required this.name,
    this.photo,
    required this.isVideo,
    required this.chatId,
    required this.chatService,
    required this.senderId,
    required this.receiverId,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: photo != null ? NetworkImage(photo!) : null,
            child: photo == null ? const Icon(Iconsax.user, size: 40) : null,
          ),
          const SizedBox(height: 20),
          Text(
            languageProvider.getString(
                isVideo ? 'call_video_label' : 'call_voice_label'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCallButton(
                Iconsax.close_circle,
                'Cancel',
                Colors.red,
                () => Navigator.pop(context),
                languageProvider,
              ),
              _buildCallButton(
                isVideo ? Iconsax.video : Iconsax.call,
                'Call',
                Colors.green,
                () async {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OutgoingCallScreen(
                        receiverId: receiverId,
                        receiverName: name,
                        receiverPhoto: photo ?? '',
                        chatId: chatId,
                        isVideo: isVideo,
                        roomName: chatId,
                      ),
                    ),
                  );
                },
                languageProvider,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
    LanguageProvider languageProvider,
  ) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          languageProvider.getString(label.toLowerCase()),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
