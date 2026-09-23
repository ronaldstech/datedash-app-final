import 'package:flutter/material.dart';

class StickerBubble extends StatelessWidget {
  final String emoji;
  final bool isMe;

  const StickerBubble({
    super.key,
    required this.emoji,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize = emoji.runes.length <= 2 ? 84 : 56;

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 190,
        minWidth: 100,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(24),
          topRight: const Radius.circular(24),
          bottomLeft: Radius.circular(isMe ? 24 : 8),
          bottomRight: Radius.circular(isMe ? 8 : 24),
        ),
        color: isMe
            ? const Color(0xFFFF4D85).withValues(alpha: 0.10)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        boxShadow: [
          BoxShadow(
            color: isMe
                ? const Color(0xFFFF4D85).withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          emoji,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.1,
            shadows: const [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 3),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}