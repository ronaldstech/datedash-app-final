import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../models/user_profile_model.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';
import '../providers/language_provider.dart';
import 'chat_screen.dart';
import '../utils/date_formatter.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late final ChatService _chatService;
  late final ProfileService _profileService;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService();
    _profileService = ProfileService();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final languageProvider = context.watch<LanguageProvider>();

    if (myUid == null) {
      return Scaffold(
        body: Center(child: Text(languageProvider.getString('signin_to_view_messages'))),
      );
    }

    return Scaffold(
      body: StreamBuilder<List<Chat>>(
        stream: _chatService.getChatsStream(myUid),
        builder: (context, snapshot) {
          final chats = snapshot.data ?? [];
          final hasError = snapshot.hasError;
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium AppBar
              SliverAppBar(
                expandedHeight: 140.0,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: Text(
                    languageProvider.getString('messages_title'),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      letterSpacing: -1,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFFF4D85).withValues(alpha: 	0.05),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Iconsax.search_normal_1),
                    onPressed: () {
                      // TODO: Implement actual search functionality
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Loading State
              if (isLoading && chats.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF4D85)),
                  ),
                ),

              // Error State
              if (hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(languageProvider),
                ),

              // NEW MATCHES SECTION (Always prioritized at top)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        languageProvider.getString('new_matches_header'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D85).withValues(alpha: 	0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: StreamBuilder<List<UserProfile>>(
                          stream: _profileService.getMatchesStream(myUid),
                          builder: (context, matchSnap) {
                            return StreamBuilder<List<Chat>>(
                              stream: _chatService.getChatsStream(myUid),
                              builder: (context, chatsSnap) {
                                final activeChatUserIds = (chatsSnap.data ?? [])
                                    .where((c) => c.lastMessage.isNotEmpty)
                                    .map((c) => c.otherUserId(myUid))
                                    .toSet();
                                final filteredCount = (matchSnap.data ?? [])
                                    .where((m) =>
                                        !activeChatUserIds.contains(m.uid))
                                    .length;
                                return Text(
                                  '$filteredCount',
                                  style: const TextStyle(
                                    color: Color(0xFFFF4D85),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: StreamBuilder<List<UserProfile>>(
                    stream: _profileService.getMatchesStream(myUid),
                    builder: (context, matchSnap) {
                      final matches = matchSnap.data ?? [];
                      if (matchSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                      }
                      if (matches.isEmpty) {
                        return _buildEmptyMatches(languageProvider);
                      }

                      // Filter matches who already have an active conversation
                      final activeChatUserIds = chats
                          .where((c) => c.lastMessage.isNotEmpty)
                          .map((c) => c.otherUserId(myUid))
                          .toSet();
                      final filteredMatches = matches
                          .where((m) => !activeChatUserIds.contains(m.uid))
                          .toList();

                      if (filteredMatches.isEmpty) {
                        return _buildEmptyMatches(languageProvider);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredMatches.length,
                        itemBuilder: (context, index) =>
                            _buildMatchItem(context, filteredMatches[index], languageProvider),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              const SliverToBoxAdapter(child: Divider(indent: 20, endIndent: 20, thickness: 0.5, height: 1)),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // MESSAGES SECTION
              if (chats.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text(
                      languageProvider.getString('recent_messages_header'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

              if (chats.isEmpty && !isLoading && !hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyMessages(languageProvider, context),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildChatTile(
                        context, chats[index], myUid, languageProvider),
                    childCount: chats.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(LanguageProvider lp) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.warning_2, size: 64, color: Colors.red.withValues(alpha: 	0.4)),
          const SizedBox(height: 16),
          Text(lp.getString('failed_load_messages'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D85), foregroundColor: Colors.white),
            child: Text(lp.getString('retry_button')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMatches(LanguageProvider lp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 	0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 	0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFF4D85).withValues(alpha: 	0.1), shape: BoxShape.circle),
              child: const Icon(Iconsax.heart_add, color: Color(0xFFFF4D85), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                lp.getString('no_matches_yet_sub'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchItem(BuildContext context, UserProfile match, LanguageProvider lp) {
    final photo = match.photos.isNotEmpty ? match.photos.first : null;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              otherUserId: match.uid!,
              otherUserName: match.firstName ?? lp.getString('user_fallback'),
              otherUserPhoto: photo,
            ),
          ),
        );
        setState(() {});
      },
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(left: 8, right: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4D85), Color(0xFFFF9A8B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF4D85).withValues(alpha: 	0.2), blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: photo != null ? NetworkImage(photo) : null,
                  child: photo == null ? const Icon(Iconsax.user, color: Colors.grey) : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              match.firstName ?? lp.getString('user_fallback'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMessages(LanguageProvider lp, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.message_2, size: 64, color: Theme.of(context).hintColor.withValues(alpha: 	0.2)),
          const SizedBox(height: 16),
          Text(lp.getString('no_conversations_yet'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(lp.getString('no_conversations_sub'), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, Chat chat, String myUid, LanguageProvider lp) {
    final otherUid = chat.otherUserId(myUid);
    final unread = chat.unreadCount[myUid] ?? 0;

    return FutureBuilder<UserProfile?>(
      future: _profileService.getUserProfile(otherUid),
      builder: (context, profileSnap) {
        final profile = profileSnap.data;
        final name = profile?.firstName ?? lp.getString('user_fallback');
        final photo = profile?.photos.isNotEmpty == true ? profile!.photos.first : null;

        return InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  otherUserId: otherUid,
                  otherUserName: name,
                  otherUserPhoto: photo,
                ),
              ),
            );
            if (result == true && mounted) setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: unread > 0 ? const Color(0xFFFF4D85) : Colors.transparent, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: photo != null ? NetworkImage(photo) : null,
                        child: photo == null ? const Icon(Iconsax.user, color: Colors.grey) : null,
                      ),
                    ),
                    if (profile?.isOnline == true)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.w700,
                                      fontSize: 16,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (chat.isSuperRequest)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('SUPER', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            chat.lastMessageTime != null ? DateFormatter.format(chat.lastMessageTime!, lp) : '',
                            style: TextStyle(
                              color: unread > 0 ? const Color(0xFFFF4D85) : Theme.of(context).hintColor,
                              fontSize: 12,
                              fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.lastMessage.isEmpty
                                  ? lp.getString('say_hello')
                                  : (chat.lastMessageSenderId == myUid ? '${lp.getString('you_prefix')} ${chat.lastMessage}' : chat.lastMessage),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unread > 0 ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).hintColor,
                                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4D85),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: const Color(0xFFFF4D85).withValues(alpha: 	0.3), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

