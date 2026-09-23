import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../models/user_profile_model.dart';
import '../providers/profile_provider.dart';
import '../providers/language_provider.dart';
import '../services/profile_service.dart';
import '../services/notification_service.dart';
import '../config/app_config.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    context.watch<LanguageProvider>();
    final profile = profileProvider.userProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFFFF4D85);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D11) : const Color(0xFFF7F7F9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? Colors.black : primaryColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Iconsax.arrow_left_2, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('REWARDS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF4D85), Color(0xFFFF8E8E)]))),
                  Positioned(right: -20, bottom: -20, child: Icon(Iconsax.cup5, size: 150, color: Colors.white.withValues(alpha: 0.15))),
                  Positioned(left: 20, bottom: 54, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${profile.credits} Sparks', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    Text('Complete challenges and claim rewards', style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12, fontWeight: FontWeight.w700)),
                  ])),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(profile, isDark),
                  const SizedBox(height: 32),
                  _buildSectionTitle('ACTIVE CHALLENGES'),
                  const SizedBox(height: 16),
                  _ChallengeCard(id: 'daily_explorer', title: 'Daily Explorer', description: 'Use Snellum for 3 hours today', reward: 500, progress: (profile.dailyUsageDuration / 10800).clamp(0.0, 1.0), progressLabel: '${(profile.dailyUsageDuration / 3600).toStringAsFixed(1)}h / 3h', isCompleted: profile.dailyUsageDuration >= 10800, isClaimed: profile.claimedRewards.contains('daily_explorer'), icon: Iconsax.timer_1, accentColor: Colors.blueAccent),
                  const SizedBox(height: 16),
                  _ChallengeCard(id: 'profile_pro', title: 'Profile Pro', description: 'Complete 100% of your profile', reward: 200, progress: profile.completionPercentage / 100, progressLabel: '${profile.completionPercentage}%', isCompleted: profile.completionPercentage >= 100, isClaimed: profile.claimedRewards.contains('profile_pro'), icon: Iconsax.user_edit, accentColor: Colors.purpleAccent),
                  const SizedBox(height: 16),
                  _ChallengeCard(id: 'trusted_member', title: 'Trusted Member', description: 'Verify your account', reward: 500, progress: profile.isVerified ? 1.0 : 0.0, progressLabel: profile.isVerified ? 'Verified' : 'Not Verified', isCompleted: profile.isVerified, isClaimed: profile.claimedRewards.contains('trusted_member'), icon: Iconsax.verify, accentColor: Colors.tealAccent),
                  const SizedBox(height: 16),
                  const _ChallengeCard(id: 'welcome_bonus', title: 'Welcome Gift', description: 'Join the Snellum community', reward: 100, progress: 1.0, progressLabel: 'Completed', isCompleted: true, isClaimed: true, icon: Iconsax.cake, accentColor: Colors.orangeAccent),
                  const SizedBox(height: 32),
                  _buildSectionTitle('INVITE & EARN'),
                  const SizedBox(height: 4),
                  Text('Earn 500 sparks for every friend who joins and verifies their email — no limit!', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 16),
                  _InviteSection(profile: profile, isDark: isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(UserProfile profile, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _buildStatItem('Sparks', profile.credits.toString(), Iconsax.wallet_3, Colors.orangeAccent),
        Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.2)),
        _buildStatItem('Claimed', profile.claimedRewards.length.toString(), Iconsax.receipt_21, const Color(0xFFFF4D85)),
        Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.2)),
        _buildStatItem('Invited', profile.referralRewardCount.toString(), Iconsax.profile_2user, Colors.greenAccent),
      ]),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 24),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
    ]);
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey));
  }
}

// ── INVITE SECTION ────────────────────────────────────────────────────────────

class _InviteSection extends StatefulWidget {
  final UserProfile profile;
  final bool isDark;
  const _InviteSection({required this.profile, required this.isDark});
  @override
  State<_InviteSection> createState() => _InviteSectionState();
}

class _InviteSectionState extends State<_InviteSection> {
  final ProfileService _svc = ProfileService();
  String? _referralCode;
  bool _loading = true;
  static const int _reward = 500;
  static const Color _green = Color(0xFF00C853);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = widget.profile.uid;
    if (uid == null) return;
    final code = (widget.profile.referralCode?.isNotEmpty == true)
        ? widget.profile.referralCode!
        : await _svc.ensureReferralCode(uid);
    if (mounted) setState(() { _referralCode = code; _loading = false; });
  }

  String get _link => '${AppConfig.referralUrlPrefix}${_referralCode ?? ''}';

  void _copy() {
    Clipboard.setData(ClipboardData(text: _link));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied!'), backgroundColor: Color(0xFFFF4D85), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)))));
  }

  void _share() {
    Clipboard.setData(ClipboardData(text: _link));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Row(children: [Icon(Icons.share, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('Link copied! Share it with friends.', style: TextStyle(color: Colors.white)))]), backgroundColor: Colors.green.shade600, behavior: SnackBarBehavior.floating, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)))));
  }

  Future<void> _claim(String invitedUid) async {
    final uid = widget.profile.uid;
    if (uid == null) return;
    try {
      await _svc.claimReferralReward(inviterUid: uid, invitedUid: invitedUid, rewardAmount: _reward);
      await NotificationService().sendNotification(recipientId: uid, senderId: 'system', senderName: 'Snellum', type: 'reward', message: 'Referral reward: +$_reward sparks added!');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Row(children: [Icon(Iconsax.coin, color: Colors.white, size: 18), SizedBox(width: 8), Text('+500 Sparks claimed!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]), backgroundColor: Colors.green.shade600, behavior: SnackBarBehavior.floating, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().contains('already claimed') ? 'Already claimed for this user' : 'Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _green.withValues(alpha: 0.3), width: 1.5), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_green.withValues(alpha: 0.12), _green.withValues(alpha: 0.04)]), borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _green.withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Iconsax.profile_2user, color: _green, size: 24)),
            const SizedBox(width: 16),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Invite Friends', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text('No limit — earn sparks for every verified friend', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: const Text('+500 ⚡', style: TextStyle(color: _green, fontWeight: FontWeight.w900, fontSize: 14))),
          ]),
        ),
        // Link + buttons
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('YOUR INVITE LINK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05))),
            child: Row(children: [
              const Icon(Iconsax.link, size: 16, color: _green),
              const SizedBox(width: 10),
              Expanded(child: _loading ? const SizedBox(height: 14, child: LinearProgressIndicator(color: _green)) : Text(_link, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87), overflow: TextOverflow.ellipsis)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: GestureDetector(onTap: _loading ? null : _copy, child: Container(height: 46, decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade100, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Iconsax.copy, size: 16, color: isDark ? Colors.white60 : Colors.black54), const SizedBox(width: 6), Text('Copy Link', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87))])))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(onTap: _loading ? null : _share, child: Container(height: 46, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_green, Color(0xFF69F0AE)], begin: Alignment.centerLeft, end: Alignment.centerRight), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: _green.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.share, size: 16, color: Colors.white), SizedBox(width: 6), Text('Share Link', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white))])))),
          ]),
          const SizedBox(height: 20),
          Text('PEOPLE YOU INVITED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey.shade500)),
          const SizedBox(height: 12),
        ])),
        // Invited users stream
        if (_referralCode != null)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _svc.getInvitedUsersStream(_referralCode!),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: _green, strokeWidth: 2)));
              final users = snap.data ?? [];
              if (users.isEmpty) {
                return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))), child: Column(children: [Icon(Iconsax.profile_add, size: 40, color: Colors.grey.shade400), const SizedBox(height: 12), Text('No one yet — share your link!', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700, fontSize: 15)), const SizedBox(height: 4), Text('Every friend who verifies their email earns you 500 sparks', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 13))])));
              }
              return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: Column(children: users.map((u) {
                final uid = u['uid'] as String;
                final name = u['firstName'] as String;
                final verified = u['isEmailVerified'] as bool;
                final claimed = widget.profile.claimedRewards.contains('referral_$uid');
                return _InvitedUserTile(uid: uid, name: name, isEmailVerified: verified, alreadyClaimed: claimed, isDark: isDark, onClaim: () => _claim(uid));
              }).toList()));
            },
          )
        else
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}

// ── INVITED USER TILE ─────────────────────────────────────────────────────────

class _InvitedUserTile extends StatefulWidget {
  final String uid;
  final String name;
  final bool isEmailVerified;
  final bool alreadyClaimed;
  final bool isDark;
  final Future<void> Function() onClaim;
  const _InvitedUserTile({required this.uid, required this.name, required this.isEmailVerified, required this.alreadyClaimed, required this.isDark, required this.onClaim});
  @override
  State<_InvitedUserTile> createState() => _InvitedUserTileState();
}

class _InvitedUserTileState extends State<_InvitedUserTile> {
  bool _claiming = false;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF00C853);
    final canClaim = widget.isEmailVerified && !widget.alreadyClaimed;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: widget.isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: canClaim ? green.withValues(alpha: 0.4) : (widget.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)), width: canClaim ? 1.5 : 1)),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: green.withValues(alpha: 0.15), shape: BoxShape.circle), child: Center(child: Text(widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?', style: const TextStyle(color: green, fontWeight: FontWeight.w900, fontSize: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(widget.isEmailVerified ? Iconsax.tick_circle5 : Iconsax.clock, size: 13, color: widget.isEmailVerified ? green : Colors.orangeAccent),
            const SizedBox(width: 4),
            Text(widget.isEmailVerified ? 'Email verified' : 'Email not verified yet', style: TextStyle(fontSize: 12, color: widget.isEmailVerified ? green : Colors.orangeAccent, fontWeight: FontWeight.w600)),
          ]),
        ])),
        if (widget.alreadyClaimed)
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Text('✓ CLAIMED', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w900)))
        else if (!widget.isEmailVerified)
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Text('PENDING', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w900)))
        else
          GestureDetector(
            onTap: _claiming ? null : () async { setState(() => _claiming = true); await widget.onClaim(); if (mounted) setState(() => _claiming = false); },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(gradient: const LinearGradient(colors: [green, Color(0xFF69F0AE)]), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: green.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]), child: _claiming ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('+500 ⚡', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
          ),
      ]),
    );
  }
}

// ── CHALLENGE CARD ────────────────────────────────────────────────────────────

class _ChallengeCard extends StatefulWidget {
  final String id;
  final String title;
  final String description;
  final int reward;
  final double progress;
  final String progressLabel;
  final bool isCompleted;
  final bool isClaimed;
  final IconData icon;
  final Color accentColor;

  const _ChallengeCard({required this.id, required this.title, required this.description, required this.reward, required this.progress, required this.progressLabel, required this.isCompleted, required this.isClaimed, required this.icon, required this.accentColor});

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  bool _isClaiming = false;

  Future<void> _handleClaim(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<ProfileProvider>();
    setState(() => _isClaiming = true);
    try {
      await provider.claimReward(widget.id, widget.reward);
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Succesfully claimed ${widget.reward} sparks!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canClaim = widget.isCompleted && !widget.isClaimed;

    return Container(
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: canClaim ? widget.accentColor.withValues(alpha: 0.5) : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)), width: canClaim ? 2 : 1), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 8))]),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(widget.icon, color: widget.accentColor, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(widget.description, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ])),
            if (widget.reward > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text('+${widget.reward}', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w900))),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: (widget.isClaimed ? Colors.green : canClaim ? widget.accentColor : Colors.grey).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Text(widget.isClaimed ? 'DONE' : canClaim ? 'READY' : 'OPEN', style: TextStyle(color: widget.isClaimed ? Colors.green : canClaim ? widget.accentColor : Colors.grey, fontSize: 10, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: widget.progress, backgroundColor: Colors.grey.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation<Color>(widget.isClaimed ? Colors.green : widget.accentColor), minHeight: 8))),
            const SizedBox(width: 12),
            Text(widget.progressLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canClaim && !_isClaiming ? () => _handleClaim(context) : null,
              style: ElevatedButton.styleFrom(backgroundColor: canClaim ? widget.accentColor : (widget.isClaimed ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)), foregroundColor: canClaim ? Colors.white : (widget.isClaimed ? Colors.green : Colors.grey), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _isClaiming ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.isClaimed ? 'CLAIMED' : (widget.isCompleted ? (widget.reward > 0 ? 'CLAIM REWARD' : 'LIMIT REACHED') : (widget.reward > 0 ? 'IN PROGRESS' : 'FREE USAGE')), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ]),
      ),
    );
  }
}
