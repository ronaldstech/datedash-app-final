import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../models/chat_model.dart';
import '../../models/gift_model.dart';
import '../../providers/language_provider.dart';
import '../../utils/date_formatter.dart';
import '../meetup_bubble.dart';
import 'voice_note_bubble.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isRecipientOnline;
  final String? otherUserPhoto;
  final String otherUserId;
  final String otherUserName;
  final LanguageProvider languageProvider;
  final Function(ChatMessage) onReply;
  final Function(ChatMessage)? onEdit;
  final Function(ChatMessage) onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isRecipientOnline,
    this.otherUserPhoto,
    required this.otherUserId,
    required this.otherUserName,
    required this.languageProvider,
    required this.onReply,
    this.onEdit,
    required this.onDelete,
  });

  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              if (isMe && message.messageType == MessageType.text && !message.isDeleted && onEdit != null)
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFFFF4D85),
                  ),
                  title: Text(languageProvider.getString('edit')),
                  onTap: () {
                    Navigator.pop(ctx);
                    onEdit!(message);
                  },
                ),
              if (isMe && !message.isDeleted)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    languageProvider.getString('delete'),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.reply_outlined, color: Colors.blue),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(ctx);
                  onReply(message);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(languageProvider.getString('delete_message_title')),
        content: Text(languageProvider.getString('delete_message_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              languageProvider.getString('cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete(message);
            },
            child: Text(
              languageProvider.getString('delete'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  String _getGiftIcon(String? type) {
    if (type == null) return '🎁';
    try {
      return GiftData.gifts.firstWhere((g) => g.name == type).icon;
    } catch (_) {
      return '🎁';
    }
  }

  Widget _buildReplyContext(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 2, height: 20, color: const Color(0xFFFF4D85)),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.replyToSenderName ?? '',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF4D85),
                  ),
                ),
                Text(
                  message.replyToText ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftBubble(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMe
              ? [const Color(0xFFFF4D85), const Color(0xFFFF85B3)]
              : [const Color(0xFF2D2D35), const Color(0xFF1A1A1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(24),
          topRight: const Radius.circular(24),
          bottomLeft: Radius.circular(isMe ? 24 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              _getGiftIcon(message.giftType),
              style: const TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isMe
                ? 'You sent a ${message.giftType}!'
                : 'Sent you a ${message.giftType}!',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${message.giftValue} credits',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperRequestBubble(BuildContext context) {
    String displayText = message.text;
    if (displayText.startsWith('🔥 Super Request: ')) {
      displayText = displayText.substring('🔥 Super Request: '.length);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFFF4D85) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMe ? 20 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 20),
        ),
        border: Border.all(color: const Color(0xFFFF8C00), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C00).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.flash5, size: 12, color: Colors.amberAccent),
              const SizedBox(width: 4),
              const Text(
                'SUPER',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  displayText,
                  style: TextStyle(
                    color: isMe ? Colors.white : null,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (message.isDeleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFFFF4D85).withValues(alpha: 0.4)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.info_circle,
              size: 14,
              color: isMe ? Colors.white70 : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              languageProvider.getString('message_deleted'),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    if (message.isSuperRequest) {
      return _buildSuperRequestBubble(context);
    }

    if (message.messageType == MessageType.gift) {
      return _buildGiftBubble(context);
    }

    if (message.messageType == MessageType.image && message.mediaUrl != null) {
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(message.mediaUrl!, fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    left: 20,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFFF4D85) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMe ? 20 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 200,
                  height: 160,
                  child: Image.network(
                    message.mediaUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 160,
                        width: 200,
                        color: Colors.grey.withValues(alpha: 0.1),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (ctx, error, stackTrace) {
                      return Container(
                        height: 160,
                        width: 200,
                        color: Colors.grey.withValues(alpha: 0.1),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Image unavailable',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (message.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : null,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (message.messageType == MessageType.voice && message.mediaUrl != null) {
      return VoiceNoteBubble(
        url: message.mediaUrl!,
        isMe: isMe,
        durationMs: message.voiceDuration,
      );
    }

    if (message.messageType == MessageType.meetup && message.mediaUrl != null) {
      return MeetupBubble(
        meetupId: message.mediaUrl!,
        isMe: isMe,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
      );
    }

    // Default: Text message
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFFF4D85) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMe ? 20 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: isMe ? Colors.white : null,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          if (message.isEdited) ...[
            const SizedBox(height: 2),
            Text(
              languageProvider.getString('edited_badge'),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Dismissible(
        key: Key(message.id),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          onReply(message);
          return false; // Prevent actual dismissal
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16),
          child: const Icon(Icons.reply, color: Color(0xFFFF4D85), size: 24),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFFFF4D85).withValues(alpha: 0.15),
                    backgroundImage: otherUserPhoto != null
                        ? NetworkImage(otherUserPhoto!)
                        : null,
                    onBackgroundImageError: otherUserPhoto != null
                        ? (exception, stackTrace) {
                            debugPrint('Error loading chat profile image: $exception');
                          }
                        : null,
                    child: otherUserPhoto == null
                        ? const Icon(
                            Iconsax.user,
                            size: 10,
                            color: Color(0xFFFF4D85),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: GestureDetector(
                    onLongPress: () => _showActionMenu(context),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (message.replyToId != null) _buildReplyContext(context),
                        _buildMessageContent(context),
                        Padding(
                          padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                          child: Text(
                            DateFormatter.formatClockTime(message.timestamp),
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(context).hintColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Icon(Icons.done, color: Colors.grey, size: 14),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
