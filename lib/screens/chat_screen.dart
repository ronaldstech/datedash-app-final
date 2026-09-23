import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'dart:io';
import 'dart:async';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';
import '../widgets/profile_detail_sheet.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/date_formatter.dart';
import 'image_editor_screen.dart';
import 'landing_screen.dart';

import '../widgets/chat/typing_indicator_dots.dart';
import '../widgets/chat/call_sheet.dart';
import '../widgets/chat/gift_picker_sheet.dart';
import '../widgets/chat/request_action_card.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../data/chat_emoji_data.dart';
import '../widgets/meetup_sheet.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;
  final Set<String> _markedAsRead = {};

  // Voice recording
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  DateTime? _recordStart;

  late String _chatId;
  bool _chatReady = false;
  ChatMessage? _editingMessage;
  ChatMessage? _replyingMessage;
  bool _isSending = false;

  // Typing status
  bool _isTypingLocal = false;
  Timer? _typingTimer;
  Stream<bool>? _otherTypingStream;

  // Search
  bool _showSearch = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  int _messageCount = 0; // used to gate voice/video calls
  bool _isMatched = false;
  bool _hasReply = false;
  int _messagesFromMeCount = 0;
  int _messagesFromOtherCount = 0;
  bool _otherUserAllowsMeetup = false;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    final id = await _chatService.getOrCreateChat(_myUid, widget.otherUserId);
    if (mounted) {
      setState(() {
        _chatId = id;
        _otherTypingStream = _chatService.getTypingStream(
          id,
          widget.otherUserId,
        );
        _chatReady = true;
      });
    }

    // Mark messages as read and expire super request flag so it disappears on chat list
    _chatService.markAsRead(id, _myUid);
    _chatService.expireSuperRequest(id);

    // Load match status
    ProfileService().checkMatchStatus(_myUid, widget.otherUserId).then((
      matched,
    ) {
      if (mounted) setState(() => _isMatched = matched);
    });

    // Load other user's profile for permissions
    ProfileService().getUserProfile(widget.otherUserId).then((profile) {
      if (mounted) {
        setState(() {
          _otherUserAllowsMeetup = profile?.allowMeetupRequests ?? false;
        });
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _updateTypingStatus(bool isCurrentlyTyping) {
    if (!_chatReady) return;
    if (_isTypingLocal != isCurrentlyTyping) {
      _isTypingLocal = isCurrentlyTyping;
      _chatService.setTypingStatus(_chatId, _myUid, isCurrentlyTyping);
    }

    _typingTimer?.cancel();
    if (isCurrentlyTyping) {
      _typingTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _isTypingLocal) {
          _isTypingLocal = false;
          _chatService.setTypingStatus(_chatId, _myUid, false);
        }
      });
    }
  }

  Future<bool> _checkAndConsumeCredits() async {
    final profileProvider = context.read<ProfileProvider>();
    final lp = context.read<LanguageProvider>();
    final user = profileProvider.userProfile;

    if (user == null) return false;

    // Premium membership users have unlimited messages (0 sparks)
    if (user.isPremium) return true;

    // Non-membership users are charged 10 sparks per message
    if (user.credits >= 10) {
      try {
        await profileProvider.useCredits(10);
        return true;
      } catch (e) {
        debugPrint('Error deducting credits: $e');
        return false;
      }
    } else {
      _showInsufficientCreditsDialog(lp);
      return false;
    }
  }

  void _showInsufficientCreditsDialog(LanguageProvider lp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Iconsax.wallet_3, color: Color(0xFFFF4D85)),
            const SizedBox(width: 12),
            Text(lp.getString('insufficient_credits_title')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lp.getString('insufficient_credits_msg')),
            const SizedBox(height: 12),
            Text(
              lp.getString('premium_benefit_msg'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lp.getString('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ProfileProvider>().navigateToPremium(0);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D85),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(lp.getString('upgrade_to_premium')),
          ),
        ],
      ),
    );
  }

  void _handleSendOrRecord() async {
    if (_isRecording) {
      _stopAndSendRecording();
    } else if (_messageController.text.trim().isNotEmpty ||
        _editingMessage != null) {
      if (_editingMessage != null) {
        _sendMessage();
        return;
      }
      if (await _checkAndConsumeCredits()) {
        _sendMessage();
      }
    } else {
      if (await _checkAndConsumeCredits()) {
        _startRecording();
      }
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_chatReady || _isSending) return;

    final languageProvider = context.read<LanguageProvider>();
    setState(() => _isSending = true);

    final msgToEdit = _editingMessage;
    _messageController.clear();
    _updateTypingStatus(false);
    setState(() => _editingMessage = null);

    try {
      if (msgToEdit != null) {
        await _chatService.editMessage(_chatId, msgToEdit.id, text);
      } else {
        await _chatService.sendMessage(
          chatId: _chatId,
          senderId: _myUid,
          receiverId: widget.otherUserId,
          text: text,
          replyToId: _replyingMessage?.id,
          replyToText: _replyingMessage?.text,
          replyToSenderName: _replyingMessage?.senderId == _myUid
              ? 'You'
              : widget.otherUserName,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${languageProvider.getString('chat_error_sending')}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _replyingMessage = null;
        });
      }
      _scrollToBottom();
    }
  }

  void _sendSticker(ChatSticker sticker) async {
    if (!_chatReady) return;

    final languageProvider = context.read<LanguageProvider>();

    if (await _checkAndConsumeCredits()) {
      try {
        await _chatService.sendMessage(
          chatId: _chatId,
          senderId: _myUid,
          receiverId: widget.otherUserId,
          text: sticker.emoji,
          messageType: MessageType.sticker,
        );
        if (mounted) {
          setState(() {
            _replyingMessage = null;
            _editingMessage = null;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${languageProvider.getString('chat_error_sending')}: $e',
              ),
            ),
          );
        }
      }
      _scrollToBottom();
    }
  }

  void _sendSuperRequest() async {
    final text = _messageController.text.trim();
    final lp = context.read<LanguageProvider>();
    final displayMessage = text.isEmpty ? 'Sent a Super Request! 🔥' : text;

    final profileProvider = context.read<ProfileProvider>();
    final user = profileProvider.userProfile;

    if (user == null) return;

    if (user.credits < 20) {
      _showInsufficientCreditsDialog(lp);
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E101D),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFFF8C00).withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D85).withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4D85), Color(0xFFFF8C00)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4D85).withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Iconsax.flash5,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SEND SUPER REQUEST',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Move your message to the top of ${widget.otherUserName}\'s list with a glowing priority highlight!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, color: Colors.amberAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Cost: 20 Sparks',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        lp.getString('cancel'),
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D85),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: const Color(
                          0xFFFF4D85,
                        ).withValues(alpha: 0.5),
                      ),
                      child: const Text(
                        'Send Super 🔥',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isSending = true);
    try {
      await profileProvider.useCredits(20);
      await _chatService.sendSuperRequest(
        chatId: _chatId,
        senderId: _myUid,
        receiverId: widget.otherUserId,
        text: displayMessage,
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending Super Request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _startRecording() async {
    final languageProvider = context.read<LanguageProvider>();
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getString('microphone_permission_denied'),
            ),
          ),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    setState(() {
      _isRecording = true;
      _recordStart = DateTime.now();
      _recordDuration = Duration.zero;
    });

    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
    } catch (e) {
      debugPrint('Error starting recorder: $e');
      if (mounted) setState(() => _isRecording = false);
      return;
    }

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isRecording || !mounted) return false;
      setState(() {
        _recordDuration = DateTime.now().difference(
          _recordStart ?? DateTime.now(),
        );
      });
      return _isRecording;
    });
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;

    final voiceDurationMs = DateTime.now()
        .difference(_recordStart ?? DateTime.now())
        .inMilliseconds;
    final languageProvider = context.read<LanguageProvider>();

    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
    });

    if (path == null || !_chatReady) return;

    final file = File(path);
    if (!file.existsSync() || file.lengthSync() == 0) return;

    setState(() => _isSending = true);

    try {
      final mediaUrl = await _chatService.uploadVoiceFile(
        filePath: path,
        chatId: _chatId,
        userId: _myUid,
      );

      await _chatService.sendMediaMessage(
        chatId: _chatId,
        senderId: _myUid,
        receiverId: widget.otherUserId,
        text: '',
        messageType: MessageType.voice,
        mediaUrl: mediaUrl,
        voiceDuration: voiceDurationMs,
        replyToId: _replyingMessage?.id,
        replyToText: _replyingMessage?.text,
        replyToSenderName: _replyingMessage?.senderId == _myUid
            ? 'You'
            : widget.otherUserName,
      );
      setState(() => _replyingMessage = null);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${languageProvider.getString('error_sending_voice')}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _cancelRecording() async {
    await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
    });
  }

  Future<void> _pickImage() async {
    final languageProvider = context.read<LanguageProvider>();
    if (await _checkAndConsumeCredits()) {
      try {
        try {
          LandingScreen.ignoreNextLock = true;
        } catch (_) {}
        final picker = ImagePicker();
        final image = await picker.pickImage(source: ImageSource.gallery);
        if (image == null || !mounted) return;

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageEditorScreen(imageFile: File(image.path)),
          ),
        );

        if (result == null) return;

        final File finalFile = result['file'];
        final String caption = result['caption'] ?? '';

        setState(() => _isSending = true);

        final mediaUrl = await _chatService.uploadFile(
          filePath: finalFile.path,
          fileType: 'images',
          chatId: _chatId,
          userId: _myUid,
        );

        await _chatService.sendMediaMessage(
          chatId: _chatId,
          senderId: _myUid,
          receiverId: widget.otherUserId,
          text: caption,
          messageType: MessageType.image,
          mediaUrl: mediaUrl,
          replyToId: _replyingMessage?.id,
          replyToText: _replyingMessage?.text,
          replyToSenderName: _replyingMessage?.senderId == _myUid
              ? 'You'
              : widget.otherUserName,
        );

        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${languageProvider.getString('error_uploading_image')}: $e',
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSending = false;
            _replyingMessage = null;
          });
        }
      }
    }
  }

  void _showCallLockedSnack() {
    final lp = context.read<LanguageProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Iconsax.lock, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lp.getString('calls_locked_message'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF4D85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showVoiceCall() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => CallSheet(
        name: widget.otherUserName,
        photo: widget.otherUserPhoto,
        isVideo: false,
        chatId: _chatId,
        chatService: _chatService,
        senderId: _myUid,
        receiverId: widget.otherUserId,
      ),
    );
  }

  void _showVideoCall() {
    final profileProvider = context.read<ProfileProvider>();
    final user = profileProvider.userProfile;
    final isPremiumOrElite =
        user != null &&
        user.isPremium &&
        (user.premiumType?.toUpperCase() == 'PREMIUM' ||
            user.premiumType?.toUpperCase() == 'ELITE');

    if (!isPremiumOrElite) {
      _showUpgradeToPremiumOrEliteDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => CallSheet(
        name: widget.otherUserName,
        photo: widget.otherUserPhoto,
        isVideo: true,
        chatId: _chatId,
        chatService: _chatService,
        senderId: _myUid,
        receiverId: widget.otherUserId,
      ),
    );
  }

  void _showUpgradeToPremiumOrEliteDialog() {
    final lp = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Iconsax.video5, color: Color(0xFFFF4D85)),
            SizedBox(width: 12),
            Text(
              'Premium Feature',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: const Text(
          'Video calling is a Premium and Elite feature. Upgrade your plan to Premium or Elite to make unlimited video calls!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              lp.getString('cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ProfileProvider>().navigateToPremium(0);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D85),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUserProfile() async {
    final profile = await ProfileService().getUserProfile(widget.otherUserId);
    if (profile != null && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ProfileDetailSheet(
          profile: profile,
          onLike: () {},
          onDislike: () {},
          onMessage: () => Navigator.pop(context),
        ),
      );
    }
  }

  void _clearChatConfirm() {
    final languageProvider = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          languageProvider.getString('clear_chat_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          languageProvider
              .getString('clear_chat_confirm_message')
              .replaceAll('{name}', widget.otherUserName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(languageProvider.getString('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _chatService.clearChat(_chatId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        languageProvider.getString('chat_cleared_snack'),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: Text(languageProvider.getString('reset')),
          ),
        ],
      ),
    );
  }

  void _showReportUserDialog() {
    String selectedReason = 'Inappropriate Messages';
    final reasons = [
      'Inappropriate Messages',
      'Harassment or Bullying',
      'Fake Profile or Spam',
      'Scam or Fraud',
      'Nudity or Explicit Content',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Iconsax.warning_2, color: Colors.orangeAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Report ${widget.otherUserName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please select a reason for reporting this profile:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: selectedReason,
                onChanged: (val) {
                  if (val != null) setStateDialog(() => selectedReason = val);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: reasons
                      .map(
                        (r) => RadioListTile<String>(
                          title: Text(r, style: const TextStyle(fontSize: 14)),
                          value: r,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: const Color(0xFFFF4D85),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance.collection('reports').add({
                    'reporterId': FirebaseAuth.instance.currentUser?.uid,
                    'reportedId': widget.otherUserId,
                    'reason': selectedReason,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Report submitted. Thank you for keeping DateDash safe.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error reporting user: $e');
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockUserConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Iconsax.user_remove, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Block ${widget.otherUserName}?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'You will no longer see their messages, and they will not be able to find your profile or contact you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              nav.pop();
              try {
                final pp = context.read<ProfileProvider>();
                if (pp.userProfile != null) {
                  if (!pp.userProfile!.blockedUsers.contains(
                    widget.otherUserId,
                  )) {
                    pp.userProfile!.blockedUsers.add(widget.otherUserId);
                    await pp.saveUserProfile(
                      pp.userProfile!.uid!,
                      pp.userProfile!,
                    );
                  }
                }
                await FirebaseFirestore.instance
                    .collection('blocked_users')
                    .add({
                      'blockerId': FirebaseAuth.instance.currentUser?.uid,
                      'blockedId': widget.otherUserId,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '${widget.otherUserName} has been blocked.',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  nav.pop(true);
                }
              } catch (e) {
                debugPrint('Error blocking user: $e');
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_chatReady) {
      _chatService.setTypingStatus(_chatId, _myUid, false);
    }
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();

    if (!_chatReady) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Iconsax.arrow_left_2),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: Text(widget.otherUserName),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Return true to parent screen on pop
      },
      child: StreamBuilder<bool>(
        stream: _chatService.getUserOnlineStatus(widget.otherUserId),
        builder: (context, onlineSnapshot) {
          final isRecipientOnline = onlineSnapshot.data ?? false;

          return StreamBuilder<Chat?>(
            stream: _chatService.getChatStream(_chatId),
            builder: (context, chatSnapshot) {
              final chat = chatSnapshot.data;
              final isRestricted =
                  !_isMatched &&
                  !_hasReply &&
                  _messagesFromMeCount >= 1 &&
                  chat?.requestStatus != 'accepted';

              return Scaffold(
                appBar: AppBar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  titleSpacing: 0,
                  leadingWidth: 40,
                  leading: IconButton(
                    icon: const Icon(Iconsax.arrow_left_2),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                  title: GestureDetector(
                    onTap: _showUserProfile,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: const Color(
                            0xFFFF4D85,
                          ).withValues(alpha: 0.2),
                          backgroundImage: widget.otherUserPhoto != null
                              ? NetworkImage(widget.otherUserPhoto!)
                              : null,
                          onBackgroundImageError: widget.otherUserPhoto != null
                              ? (e, s) => debugPrint('Error loading avatar: $e')
                              : null,
                          child: widget.otherUserPhoto == null
                              ? const Icon(
                                  Iconsax.user,
                                  size: 17,
                                  color: Color(0xFFFF4D85),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.otherUserName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              if (isRecipientOnline)
                                Text(
                                  languageProvider.getString('active_now'),
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Iconsax.call,
                        color:
                            (_messagesFromMeCount >= 3 &&
                                _messagesFromOtherCount >= 3)
                            ? null
                            : Theme.of(context).disabledColor,
                      ),
                      tooltip:
                          (_messagesFromMeCount >= 3 &&
                              _messagesFromOtherCount >= 3)
                          ? languageProvider.getString('voice_call_tooltip')
                          : 'Send at least 3 messages each to unlock calls',
                      onPressed:
                          (_messagesFromMeCount >= 3 &&
                              _messagesFromOtherCount >= 3)
                          ? _showVoiceCall
                          : _showCallLockedSnack,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Iconsax.video,
                        color:
                            (_messagesFromMeCount >= 3 &&
                                _messagesFromOtherCount >= 3)
                            ? null
                            : Theme.of(context).disabledColor,
                      ),
                      tooltip:
                          (_messagesFromMeCount >= 3 &&
                              _messagesFromOtherCount >= 3)
                          ? 'Video Call'
                          : 'Send at least 3 messages each to unlock calls',
                      onPressed:
                          (_messagesFromMeCount >= 3 &&
                              _messagesFromOtherCount >= 3)
                          ? _showVideoCall
                          : _showCallLockedSnack,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Iconsax.warning_2,
                        color: Colors.orangeAccent,
                      ),
                      tooltip: 'Report User',
                      onPressed: _showReportUserDialog,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Iconsax.user_remove,
                        color: Colors.redAccent,
                      ),
                      tooltip: 'Block User',
                      onPressed: _showBlockUserConfirm,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 2),
                    PopupMenuButton<String>(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.more_vert),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (value) async {
                        switch (value) {
                          case 'meetup':
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => MeetupSheet(
                                otherUserId: widget.otherUserId,
                                otherUserName: widget.otherUserName,
                                chatId: _chatId,
                                myUid: _myUid,
                              ),
                            );
                            break;
                          case 'search':
                            setState(() => _showSearch = !_showSearch);
                            break;
                          case 'profile':
                            _showUserProfile();
                            break;
                          case 'clear':
                            _clearChatConfirm();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (_otherUserAllowsMeetup)
                          const PopupMenuItem(
                            value: 'meetup',
                            child: Row(
                              children: [
                                Icon(
                                  Iconsax.calendar_add,
                                  size: 20,
                                  color: Color(0xFFFF4D85),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Plan a Date',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'search',
                          child: Row(
                            children: [
                              const Icon(Icons.search, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                languageProvider.getString('search'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              const Icon(Iconsax.user, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                languageProvider.getString('view_profile'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'clear',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                languageProvider.getString('clear_chat_title'),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                body: Stack(
                  children: [
                    Column(
                      children: [
                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.3),
                        ),
                        // Search bar
                        if (_showSearch)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              onChanged: (v) => setState(
                                () => _searchQuery = v.toLowerCase(),
                              ),
                              decoration: InputDecoration(
                                hintText: languageProvider.getString(
                                  'search_messages_hint',
                                ),
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() {
                                    _showSearch = false;
                                    _searchQuery = '';
                                    _searchController.clear();
                                  }),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).cardColor,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        // Restriction Banner
                        if (!_isMatched &&
                            !_hasReply &&
                            _messagesFromMeCount >= 1 &&
                            (chat?.requestStatus == 'pending' ||
                                chat?.requestStatus == null))
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            color: Colors.amber.withValues(alpha: 0.12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    languageProvider
                                        .getString('chat_waiting_for_reply')
                                        .replaceAll(
                                          '{name}',
                                          widget.otherUserName,
                                        ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Messages Stream
                        Expanded(
                          child: StreamBuilder<List<ChatMessage>>(
                            stream: _chatService.getMessagesStreamSmart(
                              _chatId,
                            ),
                            builder: (context, snapshot) {
                              final messages = snapshot.data ?? [];

                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  bool needsUpdate = false;
                                  if (_messageCount != messages.length) {
                                    _messageCount = messages.length;
                                    needsUpdate = true;
                                  }

                                  final myMsgs = messages
                                      .where((m) => m.senderId == _myUid)
                                      .length;
                                  if (_messagesFromMeCount != myMsgs) {
                                    _messagesFromMeCount = myMsgs;
                                    needsUpdate = true;
                                  }

                                  final otherMsgs = messages
                                      .where(
                                        (m) => m.senderId == widget.otherUserId,
                                      )
                                      .length;
                                  if (_messagesFromOtherCount != otherMsgs) {
                                    _messagesFromOtherCount = otherMsgs;
                                    needsUpdate = true;
                                  }

                                  final hasRep = messages.any(
                                    (m) => m.senderId == widget.otherUserId,
                                  );
                                  if (_hasReply != hasRep) {
                                    _hasReply = hasRep;
                                    needsUpdate = true;
                                  }

                                  if (needsUpdate) setState(() {});
                                }
                              });

                              final filtered = _searchQuery.isEmpty
                                  ? messages
                                  : messages
                                        .where(
                                          (m) => m.text.toLowerCase().contains(
                                            _searchQuery,
                                          ),
                                        )
                                        .toList();

                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                for (final msg in messages) {
                                  if (!msg.isRead &&
                                      msg.senderId != _myUid &&
                                      !_markedAsRead.contains(msg.id)) {
                                    _markedAsRead.add(msg.id);
                                    _chatService.markMessageAsRead(
                                      _chatId,
                                      msg.id,
                                    );
                                  }
                                }
                              });

                              if (filtered.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFFF4D85,
                                          ).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _searchQuery.isNotEmpty
                                              ? Icons.search_off
                                              : Iconsax.message,
                                          size: 40,
                                          color: const Color(0xFFFF4D85),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? languageProvider.getString(
                                                'no_messages_found',
                                              )
                                            : languageProvider
                                                  .getString('say_hi_to')
                                                  .replaceAll(
                                                    '{name}',
                                                    widget.otherUserName,
                                                  ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? languageProvider.getString(
                                                'try_different_search',
                                              )
                                            : languageProvider.getString(
                                                'start_conversation',
                                              ),
                                        style: TextStyle(
                                          color: Theme.of(context).hintColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_scrollController.hasClients &&
                                    _scrollController.position.maxScrollExtent >
                                        0) {
                                  _scrollController.animateTo(
                                    _scrollController.position.maxScrollExtent,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                  );
                                }
                              });

                              return ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final msg = filtered[index];
                                  final isMe = msg.senderId == _myUid;
                                  final prevMsg = index > 0
                                      ? filtered[index - 1]
                                      : null;
                                  final showDateDivider =
                                      prevMsg == null ||
                                      msg.timestamp.day !=
                                          prevMsg.timestamp.day ||
                                      msg.timestamp.month !=
                                          prevMsg.timestamp.month ||
                                      msg.timestamp.year !=
                                          prevMsg.timestamp.year;

                                  return Column(
                                    children: [
                                      if (showDateDivider)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 20,
                                          ),
                                          child: Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .dividerColor
                                                    .withValues(alpha: 0.05),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                DateFormatter.formatDateDivider(
                                                  msg.timestamp,
                                                  languageProvider,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(
                                                    context,
                                                  ).hintColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      MessageBubble(
                                        message: msg,
                                        isMe: isMe,
                                        isRecipientOnline: isRecipientOnline,
                                        otherUserPhoto: widget.otherUserPhoto,
                                        otherUserId: widget.otherUserId,
                                        otherUserName: widget.otherUserName,
                                        languageProvider: languageProvider,
                                        onReply: (replyMsg) {
                                          setState(() {
                                            _replyingMessage = replyMsg;
                                            _editingMessage = null;
                                          });
                                        },
                                        onEdit: (editMsg) {
                                          setState(() {
                                            _editingMessage = editMsg;
                                            _messageController.text =
                                                editMsg.text;
                                          });
                                        },
                                        onDelete: (delMsg) {
                                          _chatService.deleteMessage(
                                            _chatId,
                                            delMsg.id,
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        // Typing indicator bubble
                        StreamBuilder<bool>(
                          stream:
                              _otherTypingStream ?? const Stream<bool>.empty(),
                          builder: (context, typingSnapshot) {
                            final isTyping = typingSnapshot.data ?? false;
                            if (!isTyping) return const SizedBox.shrink();

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_scrollController.hasClients) {
                                _scrollController.jumpTo(
                                  _scrollController.position.maxScrollExtent,
                                );
                              }
                            });

                            return Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 8,
                                top: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(
                                      0xFFFF4D85,
                                    ).withValues(alpha: 0.15),
                                    backgroundImage:
                                        widget.otherUserPhoto != null
                                        ? NetworkImage(widget.otherUserPhoto!)
                                        : null,
                                    child: widget.otherUserPhoto == null
                                        ? const Icon(
                                            Iconsax.user,
                                            size: 10,
                                            color: Color(0xFFFF4D85),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20),
                                          bottomLeft: Radius.circular(4),
                                          bottomRight: Radius.circular(20),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '${widget.otherUserName} is typing',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color
                                                    ?.withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const SizedBox(
                                            width: 24,
                                            height: 12,
                                            child: TypingIndicatorDots(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        // Bottom Actions: Request Card, Declined Banner, or Chat Input
                        if (chat?.requestStatus == 'pending' &&
                            chat?.requestSenderId != _myUid)
                          RequestActionCard(
                            otherUserName: widget.otherUserName,
                            onAccept: () => _chatService.acceptRequest(_chatId),
                            onDecline: () =>
                                _chatService.declineRequest(_chatId),
                            languageProvider: languageProvider,
                          )
                        else if (chat?.requestStatus == 'declined')
                          DeclinedBanner(languageProvider: languageProvider)
                        else
                          ChatInputBar(
                            messageController: _messageController,
                            isRestricted: isRestricted,
                            isRecording: _isRecording,
                            recordDuration: _recordDuration,
                            isSending: _isSending,
                            editingMessage: _editingMessage,
                            replyingMessage: _replyingMessage,
                            myUid: _myUid,
                            otherUserName: widget.otherUserName,
                            languageProvider: languageProvider,
                            onPickImage: _pickImage,
                            onShowGiftPicker: () {
                              GiftPickerSheet.show(
                                context: context,
                                onSelectGift: (giftType, giftCost) {
                                  _chatService.sendGift(
                                    chatId: _chatId,
                                    senderId: _myUid,
                                    receiverId: widget.otherUserId,
                                    giftType: giftType,
                                    giftValue: giftCost,
                                  );
                                },
                              );
                            },
                            onCancelRecording: _cancelRecording,
                            onSendOrRecord: _handleSendOrRecord,
                            onCancelReply: () =>
                                setState(() => _replyingMessage = null),
                            onCancelEdit: () {
                              setState(() {
                                _editingMessage = null;
                                _messageController.clear();
                              });
                            },
                            onChanged: (val) {
                              setState(() {});
                              _updateTypingStatus(val.isNotEmpty);
                            },
                            onSendSticker: _sendSticker,
                          ),
                      ],
                    ),
                    // Floating Super Request header banner button
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _sendSuperRequest,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF4D85),
                                      Color(0xFFFF8C00),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFF4D85,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Iconsax.flash5,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Super Request',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.25,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        '20 ⚡',
                                        style: TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
