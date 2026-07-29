import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/identity_verification_service.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with TickerProviderStateMixin {
  final IdentityVerificationService _verificationService =
      IdentityVerificationService();
  final Color _primaryColor = const Color(0xFFFF4D85);

  bool _isStarting = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startVerification(
    ProfileProvider profileProvider,
    LanguageProvider lp,
  ) async {
    if (_isStarting) return;

    setState(() => _isStarting = true);

    try {
      final url = await _verificationService.createVerificationLink();
      final uri = Uri.parse(url);

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw IdentityVerificationException(
          'Could not open the verification provider.',
        );
      }

      final user = profileProvider.currentUser;
      final profile = profileProvider.userProfile;
      if (user != null && profile != null) {
        profile.verificationStatus = 'pending';
        profile.nationalId = 'Sumsub';
        profile.nationalIdUrl = url;
        await profileProvider.saveUserProfile(user.uid, profile);
      }

      _showSnack(lp.getString('verification_submitted_success'),
          isSuccess: true);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _showSnack(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : (isSuccess
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded),
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? Colors.redAccent : (isSuccess ? Colors.green : _primaryColor),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LanguageProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.userProfile;
    final status = profile?.verificationStatus ?? 'unverified';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lp.getString('verification_title'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E0B29),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              physics: const BouncingScrollPhysics(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _buildStateContent(status, profileProvider, lp),
              ),
            ),
          ),
          if (_isStarting)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _primaryColor),
                      const SizedBox(height: 20),
                      Text(
                        lp.getString('saving_label'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStateContent(
    String status,
    ProfileProvider profileProvider,
    LanguageProvider lp,
  ) {
    if (status == 'verified') {
      return _buildVerifiedState(lp);
    } else if (status == 'pending') {
      return _buildPendingState(profileProvider, lp);
    } else {
      return _buildUnverifiedState(profileProvider, lp);
    }
  }

  Widget _buildUnverifiedState(
    ProfileProvider profileProvider,
    LanguageProvider lp,
  ) {
    return Column(
      key: const ValueKey('unverified_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primaryColor.withValues(alpha: 0.15),
                Colors.purple.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(Iconsax.shield_tick5, size: 50, color: _primaryColor),
              const SizedBox(height: 16),
              Text(
                lp.getString('verification_title'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verify with Sumsub using a government ID and liveness check.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildProviderCard(),
        const SizedBox(height: 24),
        _buildTrustPoint(
          Iconsax.personalcard,
          'Government ID verification',
          'National ID cards, passports, and driving licenses are handled by the verification provider.',
        ),
        const SizedBox(height: 12),
        _buildTrustPoint(
          Iconsax.scan_barcode,
          'Automated document checks',
          'The provider checks document authenticity, tampering signals, and readable identity data.',
        ),
        const SizedBox(height: 12),
        _buildTrustPoint(
          Iconsax.profile_tick,
          'Result updates automatically',
          'Your profile becomes verified after the provider returns an approved review.',
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _startVerification(profileProvider, lp),
            icon: const Icon(Iconsax.verify),
            label: Text(
              lp.getString('start_verification_button'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Iconsax.security_safe, color: Colors.indigo),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sumsub',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Third-party identity verification for global ID documents.',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustPoint(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingState(ProfileProvider profileProvider, LanguageProvider lp) {
    return Column(
      key: const ValueKey('pending_view'),
      children: [
        const SizedBox(height: 40),
        ScaleTransition(
          scale: _pulseScale,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: const Icon(
              Iconsax.shield_search,
              color: Colors.orange,
              size: 72,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          lp.getString('verification_status_pending'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Finish any remaining Sumsub steps. Your profile updates after the provider sends the final review.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Iconsax.info_circle, color: Colors.orange, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Verification results are handled by Sumsub. You can reopen this screen later to check your profile status.',
                  style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedState(LanguageProvider lp) {
    return Column(
      key: const ValueKey('verified_view'),
      children: [
        const SizedBox(height: 50),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.verified,
            color: Colors.green,
            size: 88,
          ),
        ),
        const SizedBox(height: 36),
        Text(
          lp.getString('verification_status_verified'),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            lp.getString('verification_status_verified_sub'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
