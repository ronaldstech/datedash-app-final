import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PushNotificationService().initialize();
  await GoogleSignIn.instance.initialize(
    serverClientId: '409694106333-8703fkvopn9me0nauro1ki5frbbmamld.apps.googleusercontent.com',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const DateDashApp(),
    ),
  );
}

class DateDashApp extends StatefulWidget {
  const DateDashApp({super.key});

  @override
  State<DateDashApp> createState() => _DateDashAppState();
}

class _DateDashAppState extends State<DateDashApp> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUserOnline(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserOnline(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnline(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setUserOnline(false);
    }
  }

  Future<void> _setUserOnline(bool isOnline) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _chatService.setUserOnline(user.uid, isOnline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'DateDash',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      builder: (context, child) => AppNotificationWrapper(
        navigatorKey: _navigatorKey,
        child: CallListenerWrapper(
          navigatorKey: _navigatorKey,
          child: child!,
        ),
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
            return FutureBuilder<AppUpdateInfo?>(
              future: UpdateService().checkForUpdate(),
              builder: (context, updateSnapshot) {
                if (updateSnapshot.connectionState == ConnectionState.waiting) {
                  // Show a minimal splash while checking for updates
                  return Scaffold(
                    backgroundColor: const Color(0xFF1A0A14),
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipOval(
                            child: Image.asset(
                              'assets/images/signlogo.png',
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
          }
          return const SignInScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
