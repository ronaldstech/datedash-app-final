import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/chat_emoji_data.dart';
import '../../providers/language_provider.dart';

class EmojiStickerPanel extends StatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  final ValueChanged<ChatSticker> onStickerSelected;

  const EmojiStickerPanel({
    super.key,
    required this.onEmojiSelected,
    required this.onStickerSelected,
  });

  @override
  State<EmojiStickerPanel> createState() => _EmojiStickerPanelState();
}

class _EmojiStickerPanelState extends State<EmojiStickerPanel> {
  static const String _recentsKey = 'recent_emojis';
  static const int _maxRecents = 24;

  int _tabIndex = 0;
  int _categoryIndex = 0;
  List<String> _recentEmojis = [];

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recentEmojis = prefs.getStringList(_recentsKey) ?? [];
    });
  }

  Future<void> _recordRecent(String emoji) async {
    setState(() {
      _recentEmojis.remove(emoji);
      _recentEmojis.insert(0, emoji);
      if (_recentEmojis.length > _maxRecents) {
        _recentEmojis = _recentEmojis.sublist(0, _maxRecents);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentsKey, _recentEmojis);
  }

  void _handleEmojiTap(String emoji) {
    widget.onEmojiSelected(emoji);
    _recordRecent(emoji);
  }

  Widget _buildTabBar() {
    final languageProvider = context.watch<LanguageProvider>();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildTab(0, Iconsax.smileys, languageProvider.getString('chat_emoji_tab')),
          _buildTab(1, Iconsax.magic_star, languageProvider.getString('chat_stickers_tab')),
        ],
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF4D85), Color(0xFFFF7AA8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF4D85).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        itemCount: chatEmojiCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = _categoryIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _categoryIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40,
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [Color(0xFFFF4D85), Color(0xFFFF7AA8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: selected
                    ? null
                    : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF4D85).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                chatEmojiCategories[index].icon,
                size: 20,
                color: selected ? Colors.white : Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentsRow() {
    if (_recentEmojis.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        itemCount: _recentEmojis.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final emoji = _recentEmojis[index];
          return _buildEmojiTile(emoji, compact: true);
        },
      ),
    );
  }

  Widget _buildEmojiGrid() {
    final emojis =
        chatEmojiCategories[_categoryIndex].emojis;
    return Expanded(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) =>
            _buildEmojiTile(emojis[index]),
      ),
    );
  }

  Widget _buildEmojiTile(String emoji, {bool compact = false}) {
    return GestureDetector(
      onTap: () => _handleEmojiTap(emoji),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            emoji,
            style: TextStyle(
              fontSize: compact ? 22 : 24,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerGrid() {
    return Expanded(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: chatStickerPacks.length,
        itemBuilder: (context, index) =>
            _buildStickerTile(chatStickerPacks[index]),
      ),
    );
  }

  Widget _buildStickerTile(ChatSticker sticker) {
    return GestureDetector(
      onTap: () => widget.onStickerSelected(sticker),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: sticker.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: sticker.colors.first.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            sticker.emoji,
            style: const TextStyle(
              fontSize: 36,
              height: 1,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          _buildTabBar(),
          if (_tabIndex == 0) ...[
            _buildCategoryChips(),
            _buildRecentsRow(),
            _buildEmojiGrid(),
          ] else
            _buildStickerGrid(),
        ],
      ),
    );
  }
}