import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to track if the permission onboarding has already been shown.
const _kPermOnboardingShown = 'perm_onboarding_shown_v1';

/// Shows the permission onboarding modal once per install.
/// Returns true if the modal was shown, false if it was already shown before.
Future<bool> maybeShowPermissionOnboarding(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final alreadyShown = prefs.getBool(_kPermOnboardingShown) ?? false;
  if (alreadyShown) return false;

  if (!context.mounted) return false;

  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Permission Onboarding',
    barrierColor: Colors.black.withValues(alpha: 0.85),
    transitionDuration: const Duration(milliseconds: 500),
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, _) => const _PermissionOnboardingModal(),
  );

  await prefs.setBool(_kPermOnboardingShown, true);
  return true;
}

class _PermissionItem {
  final IconData icon;
  final Color color;
  final Color iconBg;
  final String title;
  final String description;

  const _PermissionItem({
    required this.icon,
    required this.color,
    required this.iconBg,
    required this.title,
    required this.description,
  });
}

const _permissions = [
  _PermissionItem(
    icon: Icons.notifications_rounded,
    color: Color(0xFFFF4D85),
    iconBg: Color(0x33FF4D85),
    title: 'Notifications',
    description:
        'Get instant alerts for new matches, messages, and video call requests so you never miss a connection.',
  ),
  _PermissionItem(
    icon: Icons.camera_alt_rounded,
    color: Color(0xFF7B5EA7),
    iconBg: Color(0x337B5EA7),
    title: 'Camera',
    description:
        'Take profile photos, share moments in chat, and join live video dates face-to-face.',
  ),
  _PermissionItem(
    icon: Icons.mic_rounded,
    color: Color(0xFF00BFA5),
    iconBg: Color(0x3300BFA5),
    title: 'Microphone',
    description:
        'Send voice messages and talk clearly during video and audio calls with your matches.',
  ),
  _PermissionItem(
    icon: Icons.location_on_rounded,
    color: Color(0xFFFF9800),
    iconBg: Color(0x33FF9800),
    title: 'Location',
    description:
        'Discover people near you and see how far away your potential matches are.',
  ),
];

class _PermissionOnboardingModal extends StatefulWidget {
  const _PermissionOnboardingModal();

  @override
  State<_PermissionOnboardingModal> createState() =>
      _PermissionOnboardingModalState();
}

class _PermissionOnboardingModalState
    extends State<_PermissionOnboardingModal>
    with SingleTickerProviderStateMixin {
  bool _isGranting = false;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _onAllow() async {
    setState(() => _isGranting = true);
    try {
      await Permission.location.request();
      await Permission.camera.request();
      await Permission.microphone.request();
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Best-effort — don't block the user if something fails
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _onSkip() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF140C12);
    const surfaceBg = Color(0xFF1E1320);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFFFF4D85).withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4D85).withValues(alpha: 0.15),
                      blurRadius: 60,
                      spreadRadius: -10,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Header gradient bar ---
                    Container(
                      height: 4,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFF4D85),
                            Color(0xFF7B5EA7),
                            Color(0xFF00BFA5),
                          ],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                      child: Column(
                      children: [
                        _buildHeroIcon(),
                        const SizedBox(height: 24),
                        const Text(
                          'Before We Get Started',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Snellum needs a few permissions to give you the full dating experience. Here\'s exactly why:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Column(
                            children: [
                              for (int i = 0; i < _permissions.length; i++)
                                _PermissionRow(
                                  item: _permissions[i],
                                  isLast: i == _permissions.length - 1,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        _buildAllowButton(),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: _isGranting ? null : _onSkip,
                          child: Text(
                            'Not now, maybe later',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You can always change these in Settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeroIcon() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, _) {
        return Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              startAngle: 0,
              endAngle: 6.28,
              transform: GradientRotation(
                _shimmerController.value * 6.28,
              ),
              colors: const [
                Color(0xFFFF4D85),
                Color(0xFF7B5EA7),
                Color(0xFF00BFA5),
                Color(0xFFFF9800),
                Color(0xFFFF4D85),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D85).withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3.5),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF140C12),
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllowButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4D85), Color(0xFFB040C0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4D85).withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isGranting ? null : _onAllow,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: _isGranting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Allow Permissions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final _PermissionItem item;
  final bool isLast;

  const _PermissionRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
