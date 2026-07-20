import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:ui';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const AppLockScreen({super.key, required this.onUnlock});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with TickerProviderStateMixin {
  final List<String> _enteredPin = [];
  String? _savedPin;
  bool _isBiometricEnabled = false;
  bool _isScanningBiometric = false;
  bool _biometricSuccess = false;

  double _scanProgress = 0.0;
  String _scanStatusText = 'Tap sensor to scan fingerprint';
  bool _isHolding = false;

  final Color _primaryColor = const Color(0xFFFF4D85);
  final LocalAuthentication _auth = LocalAuthentication();

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late AnimationController _scanProgressController;

  @override
  void initState() {
    super.initState();
    _loadSettings();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scanProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scanProgressController.addListener(() {
      setState(() {
        _scanProgress = _scanProgressController.value;
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanProgressController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPin = prefs.getString('app_lock_pin');
      _isBiometricEnabled = prefs.getBool('biometric_lock_enabled') ?? false;
    });

    // Auto-open biometric overlay on start if enabled
    if (_isBiometricEnabled) {
      setState(() {
        _isScanningBiometric = true;
        _scanStatusText = 'Scan fingerprint to unlock';
        _scanProgress = 0.0;
        _isHolding = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticateWithDeviceBiometrics();
      });
    }
  }

  Future<void> _authenticateWithDeviceBiometrics() async {
    if (_biometricSuccess) return;
    
    setState(() {
      _isHolding = true;
      _scanStatusText = 'Verifying identity...';
      _scanProgress = 0.0;
    });
    _scanProgressController.reset();

    try {
      final bool isSupported = await _auth.isDeviceSupported();
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      if (!isSupported || !canCheckBiometrics) {
        setState(() {
          _isHolding = false;
          _scanStatusText = 'Biometrics not supported or setup.';
        });
        return;
      }

      // Pulsing effect
      _scanProgressController.repeat();

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Verify your biometric signature to unlock DateDash',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      _scanProgressController.stop();

      if (didAuthenticate) {
        setState(() {
          _scanProgress = 1.0;
          _isHolding = false;
          _biometricSuccess = true;
          _scanStatusText = 'Verified Successfully!';
        });

        // Success feedback delay
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() {
            _isScanningBiometric = false;
          });
          widget.onUnlock();
        }
      } else {
        setState(() {
          _isHolding = false;
          _scanProgress = 0.0;
          _scanStatusText = 'Verification failed. Tap to retry.';
        });
      }
    } catch (e) {
      _scanProgressController.stop();
      setState(() {
        _isHolding = false;
        _scanProgress = 0.0;
        _scanStatusText = 'Authentication cancelled. Tap to retry.';
      });
    }
  }

  void _onNumberTap(int number) {
    if (_enteredPin.length >= 4) return;

    setState(() {
      _enteredPin.add(number.toString());
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin.removeLast();
    });
  }

  Future<void> _verifyPin() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    
    if (_enteredPin.join() == _savedPin) {
      widget.onUnlock();
    } else {
      setState(() {
        _enteredPin.clear();
      });
      // Show snack
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Incorrect PIN. Please try again.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(24),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBiometricOption = _isBiometricEnabled;

    return Scaffold(
      body: Stack(
        children: [
          // Background elegant gradient matching DateDash aesthetic
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F0F12),
                    Color(0xFF1E0B16),
                  ],
                ),
              ),
            ),
          ),

          // Glowing premium floating blurs
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryColor.withValues(alpha: 	0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryColor.withValues(alpha: 	0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Logo and Title
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 	0.03),
                        border: Border.all(color: Colors.white.withValues(alpha: 	0.08), width: 1.5),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Image.asset(
                        'assets/images/signlogo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter PIN to unlock DateDash',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 	0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // PIN indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isActive = index < _enteredPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? _primaryColor : Colors.transparent,
                          border: Border.all(
                            color: isActive ? _primaryColor : Colors.white.withValues(alpha: 	0.2),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  
                  const Spacer(flex: 2),

                  // Numeric Keypad
                  SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.45,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        // Position 9: Biometric / Cancel
                        if (index == 9) {
                          if (hasBiometricOption) {
                            return Center(
                              child: GestureDetector(
                                onTap: _authenticateWithDeviceBiometrics,
                                child: ScaleTransition(
                                  scale: _pulseScale,
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _primaryColor.withValues(alpha: 	0.1),
                                      border: Border.all(
                                        color: _primaryColor.withValues(alpha: 	0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      _biometricSuccess
                                          ? Icons.verified_user_rounded
                                          : Iconsax.finger_scan,
                                      color: _biometricSuccess ? Colors.greenAccent : _primaryColor,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }
                        // Position 11: Backspace
                        if (index == 11) {
                          return Center(
                            child: IconButton(
                              icon: Icon(Icons.backspace_outlined, color: Colors.white.withValues(alpha: 	0.7), size: 22),
                              onPressed: _onBackspace,
                            ),
                          );
                        }

                        final number = index == 10 ? 0 : index + 1;
                        return Center(
                          child: InkWell(
                            onTap: () => _onNumberTap(number),
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 	0.02),
                                border: Border.all(color: Colors.white.withValues(alpha: 	0.05), width: 1),
                              ),
                              child: Center(
                                child: Text(
                                  number.toString(),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),

          // Biometric Scanning Overlay
          if (_isScanningBiometric)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.black.withValues(alpha: 	0.75),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Tap sensor to authenticate
                        GestureDetector(
                          onTap: _authenticateWithDeviceBiometrics,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer progress ring
                              SizedBox(
                                width: 160,
                                height: 160,
                                child: AnimatedBuilder(
                                  animation: _scanProgressController,
                                  builder: (context, _) => CircularProgressIndicator(
                                    value: _scanProgress,
                                    strokeWidth: 4,
                                    backgroundColor: Colors.white.withValues(alpha: 	0.08),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _biometricSuccess ? Colors.greenAccent : _primaryColor,
                                    ),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                              ),
                              // Inner fingerprint icon
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isHolding
                                      ? _primaryColor.withValues(alpha: 	0.25)
                                      : _biometricSuccess
                                          ? Colors.greenAccent.withValues(alpha: 	0.15)
                                          : _primaryColor.withValues(alpha: 	0.1),
                                  border: Border.all(
                                    color: _isHolding
                                        ? _primaryColor.withValues(alpha: 	0.6)
                                        : _biometricSuccess
                                            ? Colors.greenAccent.withValues(alpha: 	0.5)
                                            : _primaryColor.withValues(alpha: 	0.25),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  _biometricSuccess
                                      ? Icons.verified_user_rounded
                                      : Iconsax.finger_scan5,
                                  size: 64,
                                  color: _biometricSuccess
                                      ? Colors.greenAccent
                                      : _isHolding
                                          ? _primaryColor
                                          : _primaryColor.withValues(alpha: 	0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _biometricSuccess ? 'Verified Successfully! ✓' : _scanStatusText,
                            key: ValueKey(_scanStatusText + _biometricSuccess.toString()),
                            style: TextStyle(
                              color: _biometricSuccess ? Colors.greenAccent : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isHolding ? 'Authenticating using device...' : 'Tap the icon above to unlock',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 	0.5),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 48),
                        // Use PIN instead button
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isScanningBiometric = false;
                              _scanProgress = 0.0;
                              _isHolding = false;
                              _scanProgressController.reset();
                              _scanStatusText = 'Tap sensor to scan fingerprint';
                            });
                          },
                          child: Text(
                            'Use PIN instead',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 	0.5),
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withValues(alpha: 	0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
