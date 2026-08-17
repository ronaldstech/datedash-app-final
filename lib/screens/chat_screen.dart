import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'dart:io';
import 'dart:async';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';
import '../widgets/profile_detail_sheet.dart';
import '../providers/language_provider.dart';
import 'image_editor_screen.dart';
import 'landing_screen.dart';
import '../utils/date_formatter.dart';
import '../providers/profile_provider.dart';
import '../widgets/meetup_sheet.dart';
import '../widgets/meetup_bubble.dart';
import '../models/gift_model.dart';

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
  bool _showEmojiPicker = false;
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
  bool _otherUserAllowsMeetup =
      false; // respects target user's privacy setting

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    // Obtain or create the chat ID first and show the UI immediately.
    final id = await _chatService.getOrCreateChat(_myUid, widget.otherUserId);
    if (mounted) {
      setState(() {
        _chatId = id;
        _otherTypingStream = _chatService.getTypingStream(id, widget.otherUserId);
        _chatReady = true; // UI can render now.
      });
    }

    // Fire‑and‑forget auxiliary network calls to avoid blocking UI.
    // Mark messages as read.
    _chatService.markAsRead(id, _myUid);

    // Load match status.
    ProfileService()
        .checkMatchStatus(_myUid, widget.otherUserId)
        .then((matched) {
      if (mounted) {
        setState(() {
          _isMatched = matched;
        });
      }
    });

    // Load other user's profile for booking permissions.
    ProfileService().getUserProfile(widget.otherUserId).then((profile) {
      if (mounted) {
        setState(() {
          _otherUserAllowsMeetup = profile?.allowMeetupRequests ?? false;
        });
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_chatReady || _isSending) return;

    final languageProvider = context.read<LanguageProvider>();
    setState(() => _isSending = true);
    // Clear state early
    final msgToEdit = _editingMessage;
    _messageController.clear();
    _showEmojiPicker = false;
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
                  '${languageProvider.getString('chat_error_sending')}: $e')),
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

  void _sendSuperRequest() async {
    final text = _messageController.text.trim();
    final lp = context.read<LanguageProvider>();

    // Default message if text is empty
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Send Super Request?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'This will cost 20 credits and move your chat to the top of their list with a special highlight.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Send (20 Credits)'),
          ),
        ],
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

  void _updateTypingStatus(bool isCurrentlyTyping) {
    if (!_chatReady) return;
    _typingTimer?.cancel();

    if (isCurrentlyTyping) {
      if (!_isTypingLocal) {
        _isTypingLocal = true;
        _chatService.setTypingStatus(_chatId, _myUid, true);
      }
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _isTypingLocal = false;
          _chatService.setTypingStatus(_chatId, _myUid, false);
        }
      });
    } else {
      if (_isTypingLocal) {
        _isTypingLocal = false;
        _chatService.setTypingStatus(_chatId, _myUid, false);
      }
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
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lp.getString('cancel'),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ProfileProvider>().navigateToPremium(1);
              Navigator.pop(context); // Close chat screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D85),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(lp.getString('get_credits')),
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
      // For editing, we don't charge credits (conventionally)
      if (_editingMessage != null) {
        _sendMessage();
        return;
      }

      // Check and use credits for new text messages
      if (await _checkAndConsumeCredits()) {
        _sendMessage();
      }
    } else {
      // Check credits before allowing voice recording
      if (await _checkAndConsumeCredits()) {
        _startRecording();
      }
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
                  languageProvider.getString('microphone_permission_denied'))),
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
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path);
    } catch (e) {
      debugPrint('Error starting recorder: $e');
      if (mounted) setState(() => _isRecording = false);
      return;
    }

    // Update timer every second
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isRecording || !mounted) return false;
      setState(() {
        _recordDuration =
            DateTime.now().difference(_recordStart ?? DateTime.now());
      });
      return _isRecording;
    });
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;

    final voiceDurationMs = DateTime.now().difference(_recordStart ?? DateTime.now()).inMilliseconds;
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
        replyToSenderName:
            _replyingMessage?.senderId == _myUid ? 'You' : widget.otherUserName,
      );
      setState(() {
        _replyingMessage = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${languageProvider.getString('error_sending_voice')}: $e')),
        );
      }
    } finally {
      setState(() => _isSending = false);
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
        // Prevent app lock when picking images
        try {
          LandingScreen.ignoreNextLock = true;
        } catch (_) {}
        final picker = ImagePicker();
        final image = await picker.pickImage(source: ImageSource.gallery);
        if (image == null) return;
        if (!mounted) return;

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageEditorScreen(imageFile: File(image.path)),
          ),
        );

        if (result == null) return;

        final File finalFile = result['file'];
        final String caption = result['caption'] ?? '';

        setState(() {
          _isSending = true;
          _showEmojiPicker = false;
        });

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
                    '${languageProvider.getString('error_uploading_image')}: $e')),
          );
        }
      } finally {
        setState(() {
          _isSending = false;
          _replyingMessage = null;
        });
      }
    } // closes: if (await _checkAndConsumeCredits())
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

  // ─── Call Handlers

  void _showCallLockedSnack() {
    String msg = '';
    if (_messagesFromMeCount < 3 && _messagesFromOtherCount < 3) {
      msg = 'Both you and ${widget.otherUserName} need to send at least 3 messages each to unlock calling!';
    } else if (_messagesFromMeCount < 3) {
      final rem = 3 - _messagesFromMeCount;
      msg = 'Send $rem more message${rem > 1 ? 's' : ''} to unlock calling!';
    } else if (_messagesFromOtherCount < 3) {
      final rem = 3 - _messagesFromOtherCount;
      msg = 'Wait for ${widget.otherUserName} to send $rem more message${rem > 1 ? 's' : ''} to unlock calling!';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
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
      builder: (_) => _CallSheet(
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
    final isPremiumOrElite = user != null &&
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
      builder: (_) => _CallSheet(
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
            Text('Premium Feature', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'Video calling is a Premium and Elite feature. Upgrade your plan to Premium or Elite to make unlimited video calls!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lp.getString('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ProfileProvider>().navigateToPremium(0);
              Navigator.pop(context); // Close chat screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D85),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ─── Clear Chat ───────────────────────────────────────────────────────────

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
                          languageProvider.getString('chat_cleared_snack')),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Iconsax.warning_2, color: Colors.orangeAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Report ${widget.otherUserName}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              ...reasons.map((r) => RadioListTile<String>(
                    title: Text(r, style: const TextStyle(fontSize: 14)),
                    value: r,
                    groupValue: selectedReason,
                    onChanged: (val) {
                      if (val != null) setStateDialog(() => selectedReason = val);
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: const Color(0xFFFF4D85),
                  )),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance.collection('reports').add({
                    'reporterId': FirebaseAuth.instance.currentUser?.uid,
                    'reportedId': widget.otherUserId,
                    'reason': selectedReason,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report submitted. Thank you for keeping DateDash safe.'),
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final pp = context.read<ProfileProvider>();
                if (pp.userProfile != null) {
                  if (!pp.userProfile!.blockedUsers.contains(widget.otherUserId)) {
                    pp.userProfile!.blockedUsers.add(widget.otherUserId);
                    await pp.saveUserProfile(pp.userProfile!.uid!, pp.userProfile!);
                  }
                }
                await FirebaseFirestore.instance.collection('blocked_users').add({
                  'blockerId': FirebaseAuth.instance.currentUser?.uid,
                  'blockedId': widget.otherUserId,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${widget.otherUserName} has been blocked.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  Navigator.pop(context, true);
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

    return StreamBuilder<bool>(
      stream: _chatService.getUserOnlineStatus(widget.otherUserId),
      builder: (context, onlineSnapshot) {
        final isRecipientOnline = onlineSnapshot.data ?? false;

        return StreamBuilder<Chat?>(
          stream: _chatService.getChatStream(_chatId),
          builder: (context, chatSnapshot) {
            final chat = chatSnapshot.data;
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Iconsax.arrow_left_2),
                  onPressed: () => Navigator.pop(context, true),
                ),
                title: GestureDetector(
                  onTap: _showUserProfile,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            const Color(0xFFFF4D85).withValues(alpha: 0.2),
                        backgroundImage: widget.otherUserPhoto != null
                            ? NetworkImage(widget.otherUserPhoto!)
                            : null,
                        onBackgroundImageError: (exception, stackTrace) {
                          debugPrint(
                              'Error loading app bar profile image: $exception');
                        },
                        child: widget.otherUserPhoto == null
                            ? const Icon(Iconsax.user,
                                size: 16, color: Color(0xFFFF4D85))
                            : null,
                      ),
                      const SizedBox(width: 10),
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
                    icon: Icon(
                      Iconsax.call,
                      color: (_messagesFromMeCount >= 3 && _messagesFromOtherCount >= 3)
                          ? null
                          : Theme.of(context).disabledColor,
                    ),
                    tooltip: (_messagesFromMeCount >= 3 && _messagesFromOtherCount >= 3)
                        ? languageProvider.getString('voice_call_tooltip')
                        : 'Send at least 3 messages each to unlock calls',
                    onPressed: (_messagesFromMeCount >= 3 && _messagesFromOtherCount >= 3)
                        ? _showVoiceCall
                        : _showCallLockedSnack,
                    iconSize: 17,
                  ),
                  IconButton(
                    icon: Icon(
                      Iconsax.video,
                      color: (_messagesFromMeCount >= 3 && _messagesFromOtherCount >= 3)
                          ? null
                          : Theme.of(context).disabledColor,
                    ),
                    tooltip: (_messagesFromMeCount >= 3 && _messagesFromOtherCount >= 3)
                        ? languageProvider.getString('video_call_tooltip')
                        : 'Send at least 3 messages each to unlock calls',
                    onPressed: (_messagesFromMeCount >= 3 && _messagesFromOtherCount >= 3)
                        ? _showVideoCall
                        : _showCallLockedSnack,
                    iconSize: 17,
                  ),
                  if (_otherUserAllowsMeetup)
                    IconButton(
                      icon: const Icon(Iconsax.calendar_add,
                          color: Color(0xFFFF4D85)),
                      tooltip: 'Plan a Date',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                           builder: (context) => MeetupSheet(
                            otherUserId: widget.otherUserId,
                            otherUserName: widget.otherUserName,
                            chatId: _chatId,
                            myUid: _myUid,
                          ),
                        );
                      },
                      iconSize: 17,
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) async {
                      switch (value) {
                        case 'search':
                          setState(() {
                            _showSearch = !_showSearch;
                            if (!_showSearch) {
                              _searchQuery = '';
                              _searchController.clear();
                            }
                          });
                          break;

                        case 'profile':
                          // handled inline / navigate to profile
                          break;

                        case 'clear':
                          _clearChatConfirm();
                          break;

                        case 'report':
                          _showReportUserDialog();
                          break;

                        case 'block':
                          _showBlockUserConfirm();
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'search',
                        child: Row(
                          children: [
                            const Icon(Icons.search, size: 20),
                            const SizedBox(width: 12),
                            Text(languageProvider.getString('nav_explore'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            const Icon(Iconsax.user, size: 20),
                            const SizedBox(width: 12),
                            Text(languageProvider.getString('view_profile'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            const Icon(Iconsax.warning_2,
                                size: 20, color: Colors.orangeAccent),
                            const SizedBox(width: 12),
                            const Text('Report User',
                                style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            const Icon(Iconsax.user_remove,
                                size: 20, color: Colors.redAccent),
                            const SizedBox(width: 12),
                            const Text('Block User',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 20, color: Colors.grey.shade600),
                            const SizedBox(width: 12),
                            Text(languageProvider.getString('clear_chat_title'),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                )),
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
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                      ),
                      // Search bar
                      if (_showSearch)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: (v) =>
                                setState(() => _searchQuery = v.toLowerCase()),
                            decoration: InputDecoration(
                              hintText: languageProvider
                                  .getString('search_messages_hint'),
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
                                  vertical: 0, horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      // --- Restriction Banner ---
                      if (!_isMatched &&
                          !_hasReply &&
                          _messagesFromMeCount >= 1 &&
                          (chat?.requestStatus == 'pending' ||
                              chat?.requestStatus == null))
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          color: Colors.amber.withValues(alpha: 0.12),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.amber, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  languageProvider
                                      .getString('chat_waiting_for_reply')
                                      .replaceAll(
                                          '{name}', widget.otherUserName),
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
                      Expanded(
                        child: !_chatReady
                            ? const Center(child: SizedBox.shrink())
                            : StreamBuilder<List<ChatMessage>>(
                                stream: _chatService
                                    .getMessagesStreamSmart(_chatId),
                                builder: (context, snapshot) {
                                  final messages = snapshot.data ?? [];

                                  // Update state for call-gating and message restriction
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
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
                                          .where((m) =>
                                              m.senderId == widget.otherUserId)
                                          .length;
                                      if (_messagesFromOtherCount != otherMsgs) {
                                        _messagesFromOtherCount = otherMsgs;
                                        needsUpdate = true;
                                      }

                                      final hasRep = messages.any((m) =>
                                          m.senderId == widget.otherUserId);
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
                                          .where((m) => m.text
                                              .toLowerCase()
                                              .contains(_searchQuery))
                                          .toList();

                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    for (final msg in messages) {
                                      if (!msg.isRead &&
                                          msg.senderId != _myUid &&
                                          !_markedAsRead.contains(msg.id)) {
                                        _markedAsRead.add(msg.id);
                                        _chatService.markMessageAsRead(
                                            _chatId, msg.id);
                                      }
                                    }
                                  });

                                  if (filtered.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF4D85)
                                                  .withValues(alpha: 0.1),
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
                                                    'no_messages_found')
                                                : languageProvider
                                                    .getString('say_hi_to')
                                                    .replaceAll('{name}',
                                                        widget.otherUserName),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _searchQuery.isNotEmpty
                                                ? languageProvider.getString(
                                                    'try_different_search')
                                                : languageProvider.getString(
                                                    'start_conversation'),
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .hintColor),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (_scrollController.hasClients &&
                                        _scrollController
                                                .position.maxScrollExtent >
                                            0) {
                                      _scrollController.animateTo(
                                        _scrollController
                                            .position.maxScrollExtent,
                                        duration:
                                            const Duration(milliseconds: 200),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  });

                                  return ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final msg = filtered[index];
                                      final isMe = msg.senderId == _myUid;
                                      final prevMsg = index > 0
                                          ? filtered[index - 1]
                                          : null;
                                      final showDateDivider = prevMsg == null ||
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 20),
                                              child: Center(
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .dividerColor
                                                        .withValues(alpha: 0.05),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    DateFormatter
                                                        .formatDateDivider(
                                                            msg.timestamp,
                                                            languageProvider),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .hintColor,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          _buildMessageBubble(
                                              msg,
                                              isMe,
                                              isRecipientOnline,
                                              languageProvider),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                      StreamBuilder<bool>(
                        stream: _otherTypingStream ?? const Stream<bool>.empty(),
                        builder: (context, typingSnapshot) {
                          final isTyping = typingSnapshot.data ?? false;
                          if (!isTyping) return const SizedBox.shrink();
                          
                          // Auto scroll to bottom when typing bubble appears
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                            }
                          });

                          return Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFFFF4D85).withValues(alpha: 0.15),
                                  backgroundImage: widget.otherUserPhoto != null
                                      ? NetworkImage(widget.otherUserPhoto!)
                                      : null,
                                  child: widget.otherUserPhoto == null
                                      ? const Icon(Iconsax.user, size: 10, color: Color(0xFFFF4D85))
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                    children: [
                                      Text(
                                        '${widget.otherUserName} is typing',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Three jumping dots effect
                                      SizedBox(
                                        width: 16,
                                        height: 12,
                                        child: _TypingIndicatorDots(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (chat?.requestStatus == 'pending' &&
                          chat?.requestSenderId != _myUid)
                        _buildRequestActionCard(languageProvider)
                      else if (chat?.requestStatus == 'declined')
                        _buildDeclinedBanner(languageProvider)
                      else ...[
                        if (_isRecording) _buildRecordingBar(languageProvider),
                        if (_showEmojiPicker)
                          SizedBox(
                            height: 250,
                            child: EmojiPicker(
                              onEmojiSelected: (category, emoji) {
                                _messageController.text += emoji.emoji;
                                setState(() {});
                              },
                            ),
                          ),
                        if (_replyingMessage != null) _buildReplyPreview(),
                        _buildMessageInput(languageProvider, chat),
                      ],
                    ],
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
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
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFFF4D85),
                                  width: 1.0,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Iconsax.flash,
                                    size: 22,
                                    color: Color(0xFFFF4D85),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Super Request',
                                    style: TextStyle(
                                      color: Color(0xFFFF4D85),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
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
    );
  }

  Widget _buildRecordingBar(LanguageProvider languageProvider) {
    final secs = _recordDuration.inSeconds;
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
            '${languageProvider.getString('recording_label')}  $timeStr',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFFFF4D85),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _cancelRecording,
            child: Text(
              languageProvider.getString('cancel_recording'),
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

  Widget _buildMessageInput(LanguageProvider languageProvider, Chat? chat) {
    final isRestricted = !_isMatched &&
        !_hasReply &&
        _messagesFromMeCount >= 1 &&
        chat?.requestStatus != 'accepted';

    return Container(
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
                onPressed: isRestricted ? null : _pickImage,
                color: isRestricted ? Colors.grey : const Color(0xFFFF4D85),
              ),
              IconButton(
                icon: const Icon(Iconsax.gift, color: Colors.orange),
                onPressed: isRestricted
                    ? null
                    : () => _showGiftPicker(languageProvider),
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
                        icon: Icon(Icons.emoji_emotions_outlined,
                            color: isRestricted
                                ? Colors.grey.withValues(alpha: 0.3)
                                : Colors.grey.shade400,
                            size: 22),
                        onPressed: isRestricted
                            ? null
                            : () => setState(
                                () => _showEmojiPicker = !_showEmojiPicker),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: !isRestricted,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: isRestricted
                                ? (languageProvider
                                    .getString('chat_waiting_for_reply_hint'))
                                : _editingMessage != null
                                    ? languageProvider.getString('edit_message')
                                    : languageProvider.getString('message'),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (v) {
                            setState(() {});
                            _updateTypingStatus(v.isNotEmpty);
                          },
                          onSubmitted: (_) => _handleSendOrRecord(),
                        ),
                      ),
                      if (_editingMessage != null)
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.grey, size: 20),
                          onPressed: () {
                            setState(() {
                              _editingMessage = null;
                              _messageController.clear();
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!isRestricted)
                GestureDetector(
                  onTap: _handleSendOrRecord,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF4D85),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (_isRecording ||
                              (_messageController.text.trim().isNotEmpty &&
                                  _editingMessage == null))
                          ? Iconsax.send_1
                          : _editingMessage != null
                              ? Icons.check
                              : Iconsax.microphone_2,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              if (isRestricted)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Iconsax.lock, color: Colors.white, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionMenu(ChatMessage msg, LanguageProvider lp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
              if (msg.messageType == MessageType.text)
                ListTile(
                  leading:
                      const Icon(Icons.edit_outlined, color: Color(0xFFFF4D85)),
                  title: Text(lp.getString('edit')),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingMessage = msg;
                      _messageController.text = msg.text;
                    });
                  },
                ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text(lp.getString('delete'),
                    style: const TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(msg, lp);
                },
              ),
              ListTile(
                leading: const Icon(Icons.reply_outlined, color: Colors.blue),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyingMessage = msg;
                    _editingMessage = null;
                  });
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(ChatMessage msg, LanguageProvider lp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lp.getString('delete_message_title')),
        content: Text(lp.getString('delete_message_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lp.getString('cancel'),
                style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _chatService.deleteMessage(_chatId, msg.id);
            },
            child: Text(lp.getString('delete'),
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    if (_replyingMessage == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
            top: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
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
                  _replyingMessage!.senderId == _myUid
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
                  _replyingMessage!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _replyingMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, bool isRecipientOnline,
      LanguageProvider languageProvider) {
    // Check if it's a super request from the chat model if available,
    // or from the message itself (if we added the field).
    // For now, let's assume Super Request messages are highlighted.
    // final bool isSuper = msg.text.startsWith('🔥 Super Request:') || (msg.isRead == false && msg.text.contains('Super Request'));

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Dismissible(
        key: Key(msg.id),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          setState(() {
            _replyingMessage = msg;
            _editingMessage = null;
          });
          return false; // Prevent actual dismissal
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16),
          child: const Icon(Icons.reply, color: Color(0xFFFF4D85), size: 24),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFFFF4D85).withValues(alpha: 0.15),
                    backgroundImage: widget.otherUserPhoto != null
                        ? NetworkImage(widget.otherUserPhoto!)
                        : null,
                    onBackgroundImageError: (exception, stackTrace) {
                      debugPrint(
                          'Error loading chat profile image: $exception');
                    },
                    child: widget.otherUserPhoto == null
                        ? const Icon(Iconsax.user,
                            size: 10, color: Color(0xFFFF4D85))
                        : null,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: GestureDetector(
                    onLongPress: isMe && !msg.isDeleted
                        ? () => _showActionMenu(msg, languageProvider)
                        : () => _showActionMenu(
                            msg, languageProvider), // Allow replying to others
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (msg.replyToId != null)
                          _buildReplyContext(msg, isMe),
                        _buildMessageContent(
                            msg, isMe, isRecipientOnline, languageProvider),
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 2, left: 4, right: 4),
                          child: Text(
                            DateFormatter.formatClockTime(msg.timestamp),
                            style: TextStyle(
                              fontSize: 9,
                              color:
                                  Theme.of(context).hintColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _buildTickMarks(msg, isRecipientOnline),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyContext(ChatMessage msg, bool isMe) {
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
          Container(
            width: 2,
            height: 20,
            color: const Color(0xFFFF4D85),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.replyToSenderName ?? '',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF4D85),
                  ),
                ),
                Text(
                  msg.replyToText ?? '',
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

  Widget _buildMessageContent(ChatMessage msg, bool isMe,
      bool isRecipientOnline, LanguageProvider languageProvider) {
    if (msg.isDeleted) {
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
            Icon(Iconsax.info_circle,
                size: 14, color: isMe ? Colors.white70 : Colors.grey),
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

    if (msg.messageType == MessageType.gift) {
      return _buildGiftBubble(msg, isMe);
    }

    if (msg.messageType == MessageType.image && msg.mediaUrl != null) {
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.network(
                        msg.mediaUrl!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    left: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
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
                    msg.mediaUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 160,
                        width: 200,
                        color: Colors.grey.withValues(alpha: 0.1),
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 160,
                        width: 200,
                        color: Colors.grey.withValues(alpha: 0.1),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image_outlined,
                                color: Colors.grey, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Image unavailable',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (msg.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  child: Text(
                    msg.text,
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

    if (msg.messageType == MessageType.voice && msg.mediaUrl != null) {
      return _VoiceNoteBubble(
        url: msg.mediaUrl!,
        isMe: isMe,
        durationMs: msg.voiceDuration,
      );
    }

    if (msg.messageType == MessageType.meetup && msg.mediaUrl != null) {
      return MeetupBubble(
        meetupId: msg.mediaUrl!,
        isMe: isMe,
        otherUserId: widget.otherUserId,
        otherUserName: widget.otherUserName,
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
            msg.text,
            style: TextStyle(
              color: isMe ? Colors.white : null,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          if (msg.isEdited) ...[
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

  Widget _buildTickMarks(ChatMessage msg, bool isRecipientOnline) {
    return const Icon(Icons.done, color: Colors.grey, size: 14);
  }

  Widget _buildGiftBubble(ChatMessage msg, bool isMe) {
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
              _getGiftIcon(msg.giftType),
              style: const TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isMe
                ? 'You sent a ${msg.giftType}!'
                : 'Sent you a ${msg.giftType}!',
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
              '${msg.giftValue} credits',
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

  String _getGiftIcon(String? type) {
    if (type == null) return '🎁';
    try {
      return GiftData.gifts.firstWhere((g) => g.name == type).icon;
    } catch (_) {
      return '🎁';
    }
  }

  void _showGiftPicker(LanguageProvider lp) {
    final gifts = GiftData.gifts;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final profileProvider = context.watch<ProfileProvider>();
        final userCredits = profileProvider.userProfile?.credits ?? 0;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Send a Gift',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars, color: Colors.orange, size: 16),
                        const SizedBox(width: 6),
                        Text('$userCredits',
                            style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: gifts.length,
                itemBuilder: (context, index) {
                  final gift = gifts[index];
                  final canAfford = userCredits >= gift.cost;

                  return GestureDetector(
                    onTap: () {
                      if (!canAfford) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Not enough credits!')),
                        );
                        return;
                      }
                      Navigator.pop(context);
                      _chatService.sendGift(
                        chatId: _chatId,
                        senderId: _myUid,
                        receiverId: widget.otherUserId,
                        giftType: gift.name,
                        giftValue: gift.cost,
                      );
                    },
                    child: Opacity(
                      opacity: canAfford ? 1.0 : 0.4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: gift.color.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: gift.color.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(gift.icon,
                                style: const TextStyle(fontSize: 32)),
                            const SizedBox(height: 6),
                            Text(gift.name,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${gift.cost}',
                                style: TextStyle(
                                    color: gift.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestActionCard(LanguageProvider lp) {
    return Container(
      width: double.infinity,
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
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF4D85).withValues(alpha: 0.08),
                const Color(0xFFFF85B3).withValues(alpha: 0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFF4D85).withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D85).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.message_notif,
                  color: Color(0xFFFF4D85),
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                lp.getString('message_request_title'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lp
                    .getString('message_request_desc')
                    .replaceAll('{name}', widget.otherUserName),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).hintColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _chatService.declineRequest(_chatId),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side:
                            BorderSide(color: Colors.red.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        foregroundColor: Colors.red.shade400,
                      ),
                      child: Text(
                        lp.getString('decline_request'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _chatService.acceptRequest(_chatId),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFFFF4D85),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0xFFFF4D85).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        lp.getString('accept_request'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
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
  }

  Widget _buildDeclinedBanner(LanguageProvider lp) {
    return Container(
      width: double.infinity,
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
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.lock,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lp.getString('request_declined'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Call Sheet Widget ───────────────────────────────────────────────────
class _CallSheet extends StatelessWidget {
  final String name;
  final String? photo;
  final bool isVideo;
  final String chatId;
  final ChatService chatService;
  final String senderId;
  final String receiverId;

  const _CallSheet({
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
          Text(isVideo ? 'Video Call' : 'Voice Call',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCallButton(Iconsax.close_circle, 'Cancel', Colors.red,
                  () => Navigator.pop(context), languageProvider),
              _buildCallButton(
                  isVideo ? Iconsax.video : Iconsax.call, 'Call', Colors.green,
                  () async {
                // Call logic
                Navigator.pop(context);
              }, languageProvider),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton(IconData icon, String label, Color color,
      VoidCallback onTap, LanguageProvider languageProvider) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(languageProvider.getString(label.toLowerCase()),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ─── Voice Note Playback Bubble ──────────────────────────────────────────────

class _VoiceNoteBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  final int? durationMs;

  const _VoiceNoteBubble({
    required this.url,
    required this.isMe,
    this.durationMs,
  });

  @override
  State<_VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<_VoiceNoteBubble> with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  late Duration _duration;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _duration = widget.durationMs != null
        ? Duration(milliseconds: widget.durationMs!)
        : Duration.zero;

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (_playerState == PlayerState.playing) {
        _player.pause();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    final bubbleColor =
        widget.isMe ? const Color(0xFFFF4D85) : Theme.of(context).cardColor;
    final contentColor = widget.isMe ? Colors.white : const Color(0xFFFF4D85);
    final textColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.85)
        : Theme.of(context).textTheme.bodySmall?.color;

    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(widget.isMe ? 20 : 4),
          bottomRight: Radius.circular(widget.isMe ? 4 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _togglePlay,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: contentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: contentColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waveform progress bar
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: contentColor,
                    inactiveTrackColor: contentColor.withValues(alpha: 0.25),
                    thumbColor: contentColor,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (val) {
                      final seekTo = Duration(
                          milliseconds:
                              (_duration.inMilliseconds * val).round());
                      _player.seek(seekTo);
                    },
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(fontSize: 10, color: textColor),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(fontSize: 10, color: textColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Typing Indicator Animated Dots ──────────────────────────────────────────
class _TypingIndicatorDots extends StatefulWidget {
  @override
  State<_TypingIndicatorDots> createState() => _TypingIndicatorDotsState();
}

class _TypingIndicatorDotsState extends State<_TypingIndicatorDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Calculate a delayed offset for each dot to make them bounce sequentially
        final double delay = index * 0.2;
        double value = _controller.value - delay;
        if (value < 0.0) value += 1.0;
        
        final double yOffset = (value <= 0.5) 
            ? -4.0 * (value / 0.5) * (1.0 - (value / 0.5)) // Sine bounce curve
            : 0.0;

        return Transform.translate(
          offset: Offset(0, yOffset),
          child: Container(
            width: 3.5,
            height: 3.5,
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            decoration: const BoxDecoration(
              color: Color(0xFFFF4D85),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildDot(0),
        _buildDot(1),
        _buildDot(2),
      ],
    );
  }
}
