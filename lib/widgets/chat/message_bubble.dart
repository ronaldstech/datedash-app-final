import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '../../models/chat_model.dart';
import '../../models/gift_model.dart';
import '../../providers/language_provider.dart';
import '../../utils/date_formatter.dart';
import '../meetup_bubble.dart';
import 'voice_note_bubble.dart';
import 'sticker_bubble.dart';

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
  final Function(String emoji)? onReact;
  final String? currentUserId;

  static const List<String> _emojiRow = [
    '❤️',
    '👍',
    '😂',
    '😮',
    '😢',
    '🔥',
    '🙏',
  ];

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
    this.onReact,
    this.currentUserId,
  });

  void _showReactionAndActionMenu(BuildContext context) {
    HapticFeedback.mediumImpact();

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final Offset bubbleOffset =
        renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final Size bubbleSize = renderBox?.size ?? const Size(200, 60);

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    const double emojiBarHeight = 52.0;
    const double menuApproxHeight = 160.0;
    const double totalOverlayHeight = emojiBarHeight + 8.0 + menuApproxHeight;

    final bool showAbove =
        (bubbleOffset.dy - topPadding) >= (emojiBarHeight + 30);

    double targetTop;
    if (showAbove) {
      if ((bubbleOffset.dy - topPadding) >= totalOverlayHeight + 10) {
        targetTop = bubbleOffset.dy - totalOverlayHeight - 6;
      } else {
        targetTop = bubbleOffset.dy - emojiBarHeight - 8;
      }
    } else {
      targetTop = bubbleOffset.dy + bubbleSize.height + 8;
    }

    targetTop = targetTop.clamp(
      topPadding + 10,
      screenSize.height - bottomPadding - totalOverlayHeight - 10,
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogCtx, anim1, anim2) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF222228) : Colors.white;
        final borderColor = isDark ? Colors.white12 : Colors.black12;

        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogCtx).pop(),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                top: targetTop,
                left: isMe ? null : 16,
                right: isMe ? 16 : null,
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Floating Emoji Reaction Bar
                      Container(
                        height: emojiBarHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _emojiRow.map((emoji) {
                            final bool isSelected = currentUserId != null &&
                                message.reactions[currentUserId] == emoji;
                            return InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(dialogCtx).pop();
                                onReact?.call(emoji);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 4,
                                ),
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFF4D85)
                                          .withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: const Color(0xFFFF4D85),
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                                child: Text(
                                  emoji,
                                  style: TextStyle(
                                    fontSize: isSelected ? 26 : 24,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Actions Menu Card
                      Container(
                        width: 190,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildMenuItem(
                                icon: Icons.reply_rounded,
                                iconColor: const Color(0xFFFF4D85),
                                title: languageProvider.getString('reply'),
                                onTap: () {
                                  Navigator.of(dialogCtx).pop();
                                  onReply(message);
                                },
                              ),
                              if (message.messageType == MessageType.text &&
                                  message.text.isNotEmpty &&
                                  !message.isDeleted)
                                _buildMenuItem(
                                  icon: Icons.copy_rounded,
                                  iconColor: Colors.blueAccent,
                                  title: languageProvider.getString(
                                    'copy',
                                  ),
                                  onTap: () {
                                    Navigator.of(dialogCtx).pop();
                                    Clipboard.setData(
                                      ClipboardData(text: message.text),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          languageProvider.getString(
                                            'copied_to_clipboard',
                                          ),
                                        ),
                                        duration: const Duration(seconds: 1),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              if (isMe &&
                                  message.messageType == MessageType.text &&
                                  !message.isDeleted &&
                                  onEdit != null)
                                _buildMenuItem(
                                  icon: Icons.edit_outlined,
                                  iconColor: const Color(0xFFFF85B3),
                                  title: languageProvider.getString('edit'),
                                  onTap: () {
                                    Navigator.of(dialogCtx).pop();
                                    onEdit!(message);
                                  },
                                ),
                              if (isMe && !message.isDeleted)
                                _buildMenuItem(
                                  icon: Icons.delete_outline_rounded,
                                  iconColor: Colors.redAccent,
                                  title: languageProvider.getString('delete'),
                                  isDestructive: true,
                                  onTap: () {
                                    Navigator.of(dialogCtx).pop();
                                    _confirmDelete(context);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (dialogCtx, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.redAccent : null,
              ),
            ),
          ],
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
                ? languageProvider.getString('you_sent_gift').replaceAll('{gift}', message.giftType ?? '')
                : languageProvider.getString('sent_you_gift').replaceAll('{gift}', message.giftType ?? ''),
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
              languageProvider.getString('credits_amount').replaceAll('{n}', '${message.giftValue}'),
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
                              languageProvider.getString('image_unavailable'),
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

    if (message.messageType == MessageType.sticker) {
      return StickerBubble(emoji: message.text, isMe: isMe);
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

  Widget _buildReactionsBadge(BuildContext context) {
    if (message.reactions.isEmpty) return const SizedBox.shrink();

    // Count occurrences of each emoji
    final Map<String, int> counts = {};
    for (final emoji in message.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    final bool hasMyReaction = currentUserId != null &&
        message.reactions.containsKey(currentUserId);
    final String? myReactionEmoji =
        currentUserId != null ? message.reactions[currentUserId] : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: GestureDetector(
        onTap: () {
          if (onReact != null &&
              myReactionEmoji != null &&
              counts.length == 1 &&
              counts[myReactionEmoji] == 1) {
            // Quick toggle off user's reaction
            onReact!(myReactionEmoji);
          } else {
            _showReactionAndActionMenu(context);
          }
        },
        onLongPress: () => _showReactionAndActionMenu(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: hasMyReaction
                ? const Color(0xFFFF4D85).withValues(alpha: isDark ? 0.25 : 0.12)
                : (isDark ? const Color(0xFF2C2C32) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasMyReaction
                  ? const Color(0xFFFF4D85).withValues(alpha: 0.6)
                  : Theme.of(context).dividerColor.withValues(alpha: 0.2),
              width: hasMyReaction ? 1.2 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...counts.keys.take(3).map(
                    (emoji) => Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
              if (message.reactions.length > 1) ...[
                const SizedBox(width: 2),
                Text(
                  '${message.reactions.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: hasMyReaction
                        ? const Color(0xFFFF4D85)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ],
          ),
        ),
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
                    onLongPress: () => _showReactionAndActionMenu(context),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (message.replyToId != null) _buildReplyContext(context),
                        _buildMessageContent(context),
                        if (message.reactions.isNotEmpty)
                          _buildReactionsBadge(context),
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
