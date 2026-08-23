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
        isFirestoreVerified;
  }

  bool _shouldSendGateCode(String email) {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;
    return _gateCodeSentEmails.add(cleanEmail);
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
