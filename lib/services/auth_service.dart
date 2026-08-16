import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'notification_service.dart';
import 'profile_service.dart';
import 'email_verification_service.dart';
import '../models/user_profile_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ProfileService _profileService = ProfileService();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Get user state changes
  Stream<User?> get user => _auth.authStateChanges();

  // Sign in with email & password (enforces email verification)
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user != null) {
        final profile = await _profileService.getUserProfile(user.uid);
        final isFirestoreVerified = await EmailVerificationService().isEmailVerified(email);

        final bool isVerified = (user.emailVerified) ||
            (profile?.isEmailVerified == true) ||
            (profile?.isVerified == true) ||
            isFirestoreVerified;

        if (!isVerified) {
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'EMAIL_NOT_VERIFIED',
            message: 'Your email is not verified yet. Please verify your account before logging in.',
          );
        }
      }

      return result;
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
        // Initialize user document in Firestore with verified status, name, phone and 50 signup sparks
        await _profileService.saveUserProfile(
          cred.user!.uid,
          UserProfile(
            firstName: name,
            phoneNumber: phoneNumber,
            sparks: 50,
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
          message: '🎁 Welcome bonus: 50 free sparks added!',
        );
      }

      return cred;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);

      if (cred.user != null) {
        // Check if profile exists, if not initialize it
        final profile = await _profileService.getUserProfile(cred.user!.uid);
        if (profile == null) {
          await _profileService.saveUserProfile(
            cred.user!.uid,
            UserProfile(firstName: cred.user?.displayName, sparks: 50),
          );

          // Log the signup reward
          await NotificationService().sendNotification(
            recipientId: cred.user!.uid,
            senderId: 'system',
            senderName: 'Snellum',
            type: 'reward',
            message: '🎁 Welcome bonus: 50 free sparks added!',
          );
        }
      }

      return cred;
    } catch (e) {
      rethrow;
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
      await _googleSignIn.signOut().timeout(const Duration(seconds: 1));
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
              sparks: 50,
            ),
          );

          // Log the signup reward
          await NotificationService().sendNotification(
            recipientId: cred.user!.uid,
            senderId: 'system',
            senderName: 'Snellum',
            type: 'reward',
            message: '🎁 Welcome bonus: 50 free sparks added!',
          );
        }
      }
      return cred;
    } catch (e) {
      rethrow;
    }
  }
}
