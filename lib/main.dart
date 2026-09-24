import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/landing_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'providers/profile_provider.dart';
import 'services/chat_service.dart';
import 'widgets/call_listener_wrapper.dart';
import 'providers/language_provider.dart';
import 'widgets/match_notification_wrapper.dart';
import 'services/update_service.dart';
import 'screens/update_screen.dart';
import 'services/push_notification_service.dart';
import 'services/email_verification_service.dart';
import 'services/profile_service.dart';
import 'widgets/permission_onboarding_modal.dart';

/// Bypasses SSL certificate errors in debug mode.
/// Root cause: emulator/device clock skew makes server cert appear invalid.
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationService().initialize();
  await GoogleSignIn.instance.initialize(
    serverClientId:
        '409694106333-8703fkvopn9me0nauro1ki5frbbmamld.apps.googleusercontent.com',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const SnellumApp(),
    ),
  );
}

class SnellumApp extends StatefulWidget {
  const SnellumApp({super.key});

  @override
  State<SnellumApp> createState() => _SnellumAppState();
}

class _SnellumAppState extends State<SnellumApp> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final Set<String> _gateCodeSentEmails = <String>{};
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUserOnline(true);
    _startHeartbeat();
  }

  @override
  void dispose() {
    _stopHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    _setUserOnline(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnline(true);
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopHeartbeat();
      _setUserOnline(false);
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _setUserOnline(true);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _setUserOnline(bool isOnline) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _chatService.setUserOnline(user.uid, isOnline);
    }
  }

  Future<bool> _isEmailVerified(User user) async {
    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser ?? user;
    final usesPasswordAuth = refreshedUser.providerData.any(
      (provider) => provider.providerId == 'password',
    );

    if (!usesPasswordAuth) return true;

    final email = refreshedUser.email;
    if (email == null || email.trim().isEmpty) return false;

    final profile = await ProfileService().getUserProfile(refreshedUser.uid);
    final isFirestoreVerified = await EmailVerificationService()
        .isEmailVerified(email);

    return refreshedUser.emailVerified ||
        (profile?.isEmailVerified == true) ||
        (profile?.isPhoneVerified == true) ||
        isFirestoreVerified;
  }

  bool _shouldSendGateCode(String email) {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;
    return _gateCodeSentEmails.add(cleanEmail);
  }

  void _checkSystemThemePrompt(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    if (themeProvider.hasPromptedSystemTheme) return;

    final systemBrightness = MediaQuery.of(context).platformBrightness;
    final systemMode = systemBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!themeProvider.hasPromptedSystemTheme && mounted) {
        final navState = _navigatorKey.currentState;
        final navContext = _navigatorKey.currentContext;
        if (navState != null && navContext != null) {
          _showThemeConfirmationDialog(navContext, systemMode);
        }
      }
    });
  }

  /// Shows the permission onboarding modal on first launch.
  /// Must be called after the widget tree is fully built (use addPostFrameCallback).
  void _checkPermissionOnboarding(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navContext = _navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;
      await maybeShowPermissionOnboarding(navContext);
    });
  }

  void _showThemeConfirmationDialog(BuildContext context, ThemeMode systemMode) {
    final themeProvider = context.read<ThemeProvider>();
    final isSystemDark = systemMode == ThemeMode.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: isSystemDark ? const Color(0xFF1E101D) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isSystemDark
                        ? [const Color(0xFFFF4D85), const Color(0xFF9C27B0)]
                        : [const Color(0xFFFF8C00), const Color(0xFFFF4D85)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4D85).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  isSystemDark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Theme Preference',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isSystemDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We detected that your phone is using ${isSystemDark ? "Dark" : "Light"} Mode. Would you like Snellum to match your phone\'s theme?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isSystemDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        themeProvider.markThemePrompted();
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isSystemDark ? Colors.white30 : Colors.black26,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Keep Current',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSystemDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        themeProvider.setThemeMode(systemMode);
                        themeProvider.markThemePrompted();
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D85),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'Use ${isSystemDark ? "Dark" : "Light"}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Snellum',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      builder: (context, child) => AppNotificationWrapper(
        navigatorKey: _navigatorKey,
        child: CallListenerWrapper(navigatorKey: _navigatorKey, child: child!),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            final user = snapshot.data!;
            return FutureBuilder<bool>(
              future: _isEmailVerified(user),
              builder: (context, verificationSnapshot) {
                if (verificationSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (verificationSnapshot.data != true) {
                  final email = user.email ?? '';
                  return VerifyEmailScreen(
                    email: email,
                    sendCodeOnOpen: _shouldSendGateCode(email),
                  );
                }

                return FutureBuilder<AppUpdateInfo?>(
                  future: UpdateService().checkForUpdate(),
                  builder: (context, updateSnapshot) {
                    if (updateSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      // Show a minimal splash while checking for updates
                      return Scaffold(
                        backgroundColor: const Color(0xFF1A0A14),
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipOval(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 32),
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFF4D85),
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (updateSnapshot.data != null) {
                      return UpdateScreen(info: updateSnapshot.data!);
                    }
                    _checkPermissionOnboarding(context);
                    _checkSystemThemePrompt(context);
                    return const LandingScreen();
                  },
                );
              },
            );
          }
          return const SignInScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
