import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class ChatEmojiCategory {
  final String name;
  final IconData icon;
  final List<String> emojis;

  const ChatEmojiCategory({
    required this.name,
    required this.icon,
    required this.emojis,
  });
}

class ChatSticker {
  final String id;
  final String emoji;
  final String label;
  final List<Color> colors;

  const ChatSticker({
    required this.id,
    required this.emoji,
    required this.label,
    required this.colors,
  });
}

const List<ChatEmojiCategory> chatEmojiCategories = [
  ChatEmojiCategory(
    name: 'Smileys',
    icon: Iconsax.smileys,
    emojis: [
      '😀', '😁', '😂', '🤣', '😊', '😇', '🙂', '😉',
      '😍', '😘', '😜', '🤪', '🤨', '🧐', '🤓', '😎',
      '🥳', '🤯', '😳', '🥰', '😢', '😭', '😤', '😡',
      '🤬', '😴', '🤤', '😷', '🤒', '🤕', '🥶', '😱',
      '🫠', '🥺', '😏', '😬',
    ],
  ),
  ChatEmojiCategory(
    name: 'Gestures',
    icon: Iconsax.like,
    emojis: [
      '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '👏',
      '🙌', '🙏', '🤝', '💪', '🫶', '👋', '🤚', '✋',
      '👆', '👇', '👈', '👉', '🤙', '👌🏻', '🙏🏻',
    ],
  ),
  ChatEmojiCategory(
    name: 'Hearts',
    icon: Iconsax.heart,
    emojis: [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
      '💔', '❤️‍🔥', '💕', '💞', '💓', '💗', '💖', '💘',
      '💝', '♥️', '💌', '💋', '🫶', '😻',
    ],
  ),
  ChatEmojiCategory(
    name: 'Celebrations',
    icon: Iconsax.cake,
    emojis: [
      '🎉', '🎊', '🎂', '🍰', '🍾', '🥂', '🍻', '🎁',
      '🎈', '🎆', '🎇', '✨', '🌟', '⭐', '💫', '🧨',
      '🎃', '🪅', '🏆', '🥇', '🥈', '🥉',
    ],
  ),
  ChatEmojiCategory(
    name: 'Animals',
    icon: Iconsax.tree,
    emojis: [
      '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼',
      '🐨', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔',
      '🐧', '🐦', '🦆', '🦉', '🐴', '🦋', '🐝', '🐢',
      '🐙', '🦀', '🐠', '🐬', '🐳', '🦄', '🌵', '🌺',
      '🌸', '🌻', '🌹', '🌷', '🌲', '🍀', '☘️', '🍄',
    ],
  ),
  ChatEmojiCategory(
    name: 'Food & Drinks',
    icon: Iconsax.coffee,
    emojis: [
      '🍕', '🍔', '🍟', '🌭', '🍿', '🥓', '🍗', '🍖',
      '🍜', '🍣', '🍤', '🍩', '🍪', '🍫', '🍭', '🍬',
      '🍮', '🍦', '🍧', '🍨', '🥤', '🧋', '☕', '🍵',
      '🍺', '🍷', '🍸', '🍹', '🍾', '🥂',
    ],
  ),
  ChatEmojiCategory(
    name: 'Activities',
    icon: Iconsax.medal,
    emojis: [
      '⚽', '🏀', '🏈', '⚾', '🎾', '🏐', '🏓', '🏸',
      '🥊', '🎯', '🎳', '🎮', '🎲', '🃏', '🎸', '🎺',
      '🎹', '🎥', '🎬', '🎧', '🎤', '🏆', '🏅', '🥇',
    ],
  ),
  ChatEmojiCategory(
    name: 'Travel & Magic',
    icon: Iconsax.star,
    emojis: [
      '🌍', '🌈', '☀️', '🌙', '⭐', '🌟', '⛅', '🌧️',
      '❄️', '🌊', '🏔️', '🏝️', '🚀', '✈️', '🚗', '🏎️',
      '🚲', '🌠', '🪐', '🌀', '✨', '💫',
    ],
  ),
];

const List<ChatSticker> chatStickerPacks = [
  ChatSticker(
    id: 'love_blush',
    emoji: '😍',
    label: 'Love it',
    colors: [Color(0xFFFF4D85), Color(0xFFFF85B3)],
  ),
  ChatSticker(
    id: 'on_fire',
    emoji: '🔥',
    label: 'On fire',
    colors: [Color(0xFFFF6B35), Color(0xFFFFA25E)],
  ),
  ChatSticker(
    id: 'party',
    emoji: '🎉',
    label: 'Party time',
    colors: [Color(0xFF9D4EDD), Color(0xFFD472FF)],
  ),
  ChatSticker(
    id: 'lol',
    emoji: '😂',
    label: 'LOL',
    colors: [Color(0xFFFFB020), Color(0xFFFFE259)],
  ),
  ChatSticker(
    id: 'kiss',
    emoji: '😘',
    label: 'Smooch',
    colors: [Color(0xFFFF3355), Color(0xFFFF6B81)],
  ),
  ChatSticker(
    id: 'big_hug',
    emoji: '🤗',
    label: 'Big hug',
    colors: [Color(0xFF5A6CF3), Color(0xFF8B9CFF)],
  ),
  ChatSticker(
    id: 'crying',
    emoji: '😭',
    label: 'Nooo',
    colors: [Color(0xFF3FA7F6), Color(0xFF73C8FF)],
  ),
  ChatSticker(
    id: 'dead',
    emoji: '💀',
    label: 'Dead',
    colors: [Color(0xFF485563), Color(0xFF7B8A9B)],
  ),
  ChatSticker(
    id: 'bear',
    emoji: '🐻',
    label: 'Cute',
    colors: [Color(0xFF8D6E63), Color(0xFFBCAAA4)],
  ),
  ChatSticker(
    id: 'rose',
    emoji: '🌹',
    label: 'Roses',
    colors: [Color(0xFFC2185B), Color(0xFFE91E63)],
  ),
  ChatSticker(
    id: 'rocket',
    emoji: '🚀',
    label: 'Blast off',
    colors: [Color(0xFF3949AB), Color(0xFF7986CB)],
  ),
  ChatSticker(
    id: 'rainbow',
    emoji: '🌈',
    label: 'You rock',
    colors: [Color(0xFF00897B), Color(0xFF4DD0E1)],
  ),
  ChatSticker(
    id: 'mind_blown',
    emoji: '🤯',
    label: 'Mind blown',
    colors: [Color(0xFF00BCD4), Color(0xFF4DD0E1)],
  ),
  ChatSticker(
    id: 'celebrate',
    emoji: '🥳',
    label: 'Yay!',
    colors: [Color(0xFF43A047), Color(0xFF7CB342)],
  ),
  ChatSticker(
    id: 'wow',
    emoji: '😮',
    label: 'Wow!',
    colors: [Color(0xFFF9A825), Color(0xFFFFD54F)],
  ),
  ChatSticker(
    id: 'love_hands',
    emoji: '🫶',
    label: 'Sending love',
    colors: [Color(0xFFD81B60), Color(0xFFFF80AB)],
  ),
  ChatSticker(
    id: 'heartbreak',
    emoji: '💔',
    label: 'Heartbroken',
    colors: [Color(0xFF6A6A78), Color(0xFF9E9EAC)],
  ),
  ChatSticker(
    id: 'starstruck',
    emoji: '🤩',
    label: 'Starstruck',
    colors: [Color(0xFF7E57C2), Color(0xFFB39DDB)],
  ),
  ChatSticker(
    id: 'sleepy',
    emoji: '😴',
    label: 'Good night',
    colors: [Color(0xFF5C6BC0), Color(0xFF9FA8DA)],
  ),
  ChatSticker(
    id: 'thumbs_up',
    emoji: '👍',
    label: 'Agreed',
    colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
  ),
  ChatSticker(
    id: 'angry',
    emoji: '😡',
    label: 'Not cool',
    colors: [Color(0xFFB71C1C), Color(0xFFEF5350)],
  ),
  ChatSticker(
    id: 'shy',
    emoji: '😳',
    label: 'Shy',
    colors: [Color(0xFFFF7043), Color(0xFFFFCC80)],
  ),
  ChatSticker(
    id: 'coffee',
    emoji: '☕',
    label: 'Coffee?',
    colors: [Color(0xFF5D4037), Color(0xFF8D6E63)],
  ),
  ChatSticker(
    id: 'music',
    emoji: '🎶',
    label: 'Feeling good',
    colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
  ),
];