import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../models/chat_model.dart';
import '../../providers/language_provider.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController messageController;
  final bool isRestricted;
  final bool isRecording;
  final Duration recordDuration;
  final bool isSending;
  final ChatMessage? editingMessage;
  final ChatMessage? replyingMessage;
  final String myUid;
  final String otherUserName;
  final LanguageProvider languageProvider;
  final VoidCallback onPickImage;
  final VoidCallback onShowGiftPicker;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendOrRecord;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;
  final ValueChanged<String> onChanged;

  const ChatInputBar({
    super.key,
    required this.messageController,
    required this.isRestricted,
    required this.isRecording,
    required this.recordDuration,
    required this.isSending,
    this.editingMessage,
    this.replyingMessage,
    required this.myUid,
    required this.otherUserName,
    required this.languageProvider,
    required this.onPickImage,
    required this.onShowGiftPicker,
    required this.onCancelRecording,
    required this.onSendOrRecord,
    required this.onCancelReply,
    required this.onCancelEdit,
    required this.onChanged,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _showEmojiPicker = false;

  Widget _buildRecordingBar() {
    final secs = widget.recordDuration.inSeconds;
    final timeStr =
        '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFFFF4D85).withValues(alpha: 0.05),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Color(0xFFFF4D85), size: 10),
          const SizedBox(width: 10),
          Text(
            '${widget.languageProvider.getString('recording_label')}  $timeStr',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFFFF4D85),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: widget.onCancelRecording,
            child: Text(
              widget.languageProvider.getString('cancel_recording'),
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    if (widget.replyingMessage == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.replyingMessage!.senderId == widget.myUid
                      ? 'Replying to yourself'
                      : 'Replying to ${widget.otherUserName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF4D85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.replyingMessage!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isRecording) _buildRecordingBar(),
        if (_showEmojiPicker)
          SizedBox(
            height: 250,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                widget.messageController.text += emoji.emoji;
                widget.onChanged(widget.messageController.text);
              },
            ),
          ),
        if (widget.replyingMessage != null) _buildReplyPreview(),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.add_circle, color: Color(0xFFFF4D85)),
                    onPressed: widget.isRestricted ? null : widget.onPickImage,
                    color: widget.isRestricted ? Colors.grey : const Color(0xFFFF4D85),
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.gift, color: Colors.orange),
                    onPressed: widget.isRestricted ? null : widget.onShowGiftPicker,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.emoji_emotions_outlined,
                              color: widget.isRestricted
                                  ? Colors.grey.withValues(alpha: 0.3)
                                  : Colors.grey.shade400,
                              size: 22,
                            ),
                            onPressed: widget.isRestricted
                                ? null
                                : () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                          ),
                          Expanded(
                            child: TextField(
                              controller: widget.messageController,
                              enabled: !widget.isRestricted,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: widget.isRestricted
                                    ? widget.languageProvider.getString('chat_waiting_for_reply_hint')
                                    : widget.editingMessage != null
                                        ? widget.languageProvider.getString('edit_message')
                                        : widget.languageProvider.getString('message'),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onChanged: widget.onChanged,
                              onSubmitted: (_) => widget.onSendOrRecord(),
                            ),
                          ),
                          if (widget.editingMessage != null)
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: widget.onCancelEdit,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!widget.isRestricted)
                    GestureDetector(
                      onTap: widget.onSendOrRecord,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF4D85),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          (widget.isRecording ||
                                  (widget.messageController.text.trim().isNotEmpty &&
                                      widget.editingMessage == null))
                              ? Iconsax.send_1
                              : widget.editingMessage != null
                                  ? Icons.check
                                  : Iconsax.microphone_2,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  if (widget.isRestricted)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Iconsax.lock, color: Colors.grey, size: 20),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
