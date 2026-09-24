import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'notification_service.dart';
import 'profile_service.dart';
import '../models/user_profile_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();
  // google_sign_in v7 uses a singleton — always access via GoogleSignIn.instance

  // Get user state changes
  Stream<User?> get user => _auth.authStateChanges();

  // Sign in with email & password. Verification is enforced by app routing.
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Register with email & password
  Future<UserCredential?> signUpWithEmail(
    String email,
    String password,
    String name,
    String phoneNumber,
  ) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        // Initialize user document in Firestore with verified status, name, phone and 100 signup sparks
        await _profileService.saveUserProfile(
          cred.user!.uid,
          UserProfile(
            firstName: name,
            phoneNumber: phoneNumber,
            sparks: 100,
            isEmailVerified: true,
            isVerified: true,
            verificationStatus: 'verified',
          ),
        );

        // Log the signup reward
        await NotificationService().sendNotification(
          recipientId: cred.user!.uid,
          senderId: 'system',
          senderName: 'Snellum',
          type: 'reward',
          message: '🎁 Welcome bonus: 100 free sparks added!',
        );
      }

      return cred;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google (google_sign_in v7 — uses Android Credential Manager)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);

      if (cred.user != null) {
        // Check if profile exists; if not, initialise it
        final profile = await _profileService.getUserProfile(cred.user!.uid);
        if (profile == null) {
          await _profileService.saveUserProfile(
            cred.user!.uid,
            UserProfile(firstName: cred.user?.displayName, sparks: 100),
          );

          // Log the signup reward
          await NotificationService().sendNotification(
            recipientId: cred.user!.uid,
            senderId: 'system',
            senderName: 'Snellum',
            type: 'reward',
            message: '🎁 Welcome bonus: 100 free sparks added!',
          );
        }
      }

      return cred;
    } on GoogleSignInException catch (e) {
      // google_sign_in v7 throws GoogleSignInException for all Credential
      // Manager failures (user cancelled, no account found, reauth failed…).
      // We surface only actionable errors to the caller.
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
          // User dismissed the picker — not an error, just return null.
          return null;
        case GoogleSignInExceptionCode.interrupted:
          // Flow was interrupted (background switch etc.) — treat as cancel.
          return null;
        default:
          // Any other code (reauth failed, network, config) — rethrow a
          // FirebaseAuthException so the UI can display a clean message.
          throw FirebaseAuthException(
            code: 'google-sign-in-failed',
            message:
                'Google Sign-In failed. Please make sure your Google account is set up on this device and try again.',
          );
      }
    } catch (e) {
      // Catch raw PlatformException / unexpected errors and normalise them.
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('canceled')) {
        return null;
      }
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message:
            'Could not sign in with Google. Please try again or use email/password instead.',
      );
    }
  }


  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Firebase first to immediately update the auth state/UI
      await _auth.signOut();
    } catch (e) {
      debugPrint('Firebase Auth signOut error: $e');
    }

    try {
      // Attempt Google sign out in background with a timeout so it never blocks the app
      await GoogleSignIn.instance.signOut().timeout(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('Google Sign-In signOut error: $e');
    }
  }

  // Phone Authentication
  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential> signInWithPhone(
    String verificationId,
    String smsCode,
  ) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final cred = await _auth.signInWithCredential(credential);

      if (cred.user != null) {
        // Check if profile exists, if not initialize it
        final profile = await _profileService.getUserProfile(cred.user!.uid);
        if (profile == null) {
          await _profileService.saveUserProfile(
            cred.user!.uid,
            UserProfile(
              firstName: 'User',
              phoneNumber: cred.user?.phoneNumber,
              sparks: 100,
            ),
          );

          // Log the signup reward
          await NotificationService().sendNotification(
            recipientId: cred.user!.uid,
            senderId: 'system',
            senderName: 'Snellum',
            type: 'reward',
            message: '🎁 Welcome bonus: 100 free sparks added!',
          );
        }
      }
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with a Firebase Custom Token generated by server
  Future<UserCredential> signInWithCustomToken(String customToken) async {
    try {
      return await _auth.signInWithCustomToken(customToken);
    } catch (e) {
      debugPrint('AuthService signInWithCustomToken error: $e');
      rethrow;
    }
  }

  /// Requests a custom token for the verified user UID from the custom token server
  Future<String> fetchCustomTokenForUid(String uid) async {
    try {
      final uri = Uri.parse(AppConfig.firebaseCustomTokenUrl);
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
        body: jsonEncode({'uid': uid}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['token'] != null) {
          return data['token'].toString();
        } else if (data is Map && data['customToken'] != null) {
          return data['customToken'].toString();
        } else {
          // If server returns token directly as plain string
          return response.body.trim().replaceAll('"', '');
        }
      } else {
        throw Exception('Server returned status code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('AuthService fetchCustomTokenForUid error: $e');
      rethrow;
    }
  }
}
