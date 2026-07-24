import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/update_service.dart';
import 'landing_screen.dart';

class UpdateScreen extends StatefulWidget {
  final AppUpdateInfo info;
  const UpdateScreen({super.key, required this.info});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen>
    with SingleTickerProviderStateMixin {
  double _downloadProgress = 0;
  bool _isDownloading = false;
  bool _downloadComplete = false;
  String? _errorMessage;
  String? _savedApkPath;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // Design tokens — no glows, premium dark system
  static const _bg = Color(0xFF0F0F12);
  static const _surface = Color(0xFF1A1A20);
  static const _border = Color(0xFF2A2A32);
  static const _pink = Color(0xFFFF4D85);
  static const _textPrimary = Color(0xFFF2F2F5);
  static const _textSecondary = Color(0xFF8A8A9A);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _dismiss() {
    // Replace the current route with LandingScreen so the user goes to the app
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LandingScreen()));
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _errorMessage = null;
    });

    try {
      if (Platform.isAndroid) {
        final installStatus = await Permission.requestInstallPackages.request();
        if (!installStatus.isGranted) {
          setState(() {
            _errorMessage =
                'Enable "Install unknown apps" in Settings to continue.';
            _isDownloading = false;
          });
          await openAppSettings();
          return;
        }
        await Permission.storage.request();
      }

      final dir =
          await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/snellum_update.apk';
      final old = File(savePath);
      if (old.existsSync()) old.deleteSync();

      await Dio().download(
        widget.info.downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 2),
        ),
      );

      if (mounted) {
        setState(() {
          _downloadComplete = true;
          _isDownloading = false;
          _savedApkPath = savePath;
        });
      }
      await _openInstaller(savePath);
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Download failed. Check your connection and retry.';
          _isDownloading = false;
        });
        debugPrint('DioError: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Something went wrong. Please try again.';
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _openInstaller(String path) async {
    final result = await OpenFile.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done && mounted) {
      setState(
        () => _errorMessage = 'Could not open installer: ${result.message}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.info.forceUpdate,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        if (didPop && !widget.info.forceUpdate) _dismiss();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        _buildHeroSection(),
                        const SizedBox(height: 32),
                        _divider(),
                        const SizedBox(height: 28),
                        _buildReleaseNotes(),
                        const SizedBox(height: 32),
                        _divider(),
                        const SizedBox(height: 28),
                        _buildActionSection(),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          _buildError(),
                        ],
                        if (!widget.info.forceUpdate) ...[
                          const SizedBox(height: 24),
                          Center(
                            child: GestureDetector(
                              onTap: _isDownloading ? null : _dismiss,
                              child: Text(
                                'Not Now',
                                style: TextStyle(
                                  color: _isDownloading
                                      ? _textSecondary.withValues(alpha: 0.3)
                                      : _textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                  decorationColor: _textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sections ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border, width: 0.5)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/signlogo.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Snellum',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _pink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _pink.withValues(alpha: 0.30),
                width: 0.5,
              ),
            ),
            child: const Text(
              'UPDATE',
              style: TextStyle(
                color: _pink,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plain high-contrast headline — no foreground/shader conflict
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'A better\n',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1.0,
                ),
              ),
              TextSpan(
                text: 'experience awaits.',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          "We've been working on improvements for you. Update now to get the latest features.",
          style: TextStyle(
            color: _textSecondary,
            fontSize: 14,
            height: 1.65,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildReleaseNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("WHAT'S NEW"),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border, width: 0.5),
          ),
          child: Text(
            widget.info.releaseNotes,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 14,
              height: 1.7,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('INSTALL UPDATE'),
        const SizedBox(height: 20),
        if (_isDownloading)
          _buildProgressUI()
        else if (_downloadComplete)
          _buildInstallButton()
        else
          _buildDownloadButton(),
      ],
    );
  }

  Widget _buildDownloadButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepRow('1', 'Download the latest version', true),
        const SizedBox(height: 10),
        _stepRow('2', 'Install the update', false),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _downloadAndInstall,
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_rounded, size: 18),
                SizedBox(width: 10),
                Text(
                  'Download & Install',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressUI() {
    final pct = (_downloadProgress * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Downloading update…',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            Text(
              '$pct%',
              style: const TextStyle(
                color: _pink,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _downloadProgress,
            backgroundColor: _border,
            valueColor: const AlwaysStoppedAnimation<Color>(_pink),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Keep the app open while downloading.',
          style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildInstallButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2E1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E5C32), width: 0.5),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF4CAF50),
                size: 18,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Download complete — ready to install.',
                  style: TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _openInstaller(_savedApkPath!),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.install_mobile_rounded, size: 18),
                SizedBox(width: 10),
                Text(
                  'Install Now',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5C1E1E), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFEF9A9A),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFEF9A9A),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _divider() => Container(height: 0.5, color: _border);

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 0.5, color: _border)),
      ],
    );
  }

  Widget _stepRow(String number, String text, bool active) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _pink : _surface,
            shape: BoxShape.circle,
            border: Border.all(color: active ? _pink : _border, width: 0.5),
          ),
          child: Text(
            number,
            style: TextStyle(
              color: active ? Colors.white : _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: active ? _textPrimary : _textSecondary,
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}
