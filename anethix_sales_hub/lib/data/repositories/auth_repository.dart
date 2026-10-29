import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firebase/firestore_mappers.dart';
import '../firebase/firestore_refs.dart';
import '../models/user_model.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Firebase Auth for credentials, Firestore for the profile.
///
/// The two are kept in lockstep by using the Firebase UID as the `users`
/// document id, so a signed-in UID always resolves to exactly one profile.
/// Firebase Auth persists the session itself, which is why there is no longer
/// any `SharedPreferences` bookkeeping here.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<UserModel> login(String email, String password) async {
    final normalised = email.trim().toLowerCase();

    final UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: normalised,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_signInMessage(error));
    } on FirebaseException catch (error) {
      throw AuthException(_networkMessage(error));
    }

    final uid = credential.user?.uid;
    if (uid == null) {
      throw const AuthException('Sign-in failed. Please try again.');
    }

    final user = await _profileFor(uid);
    if (user == null) {
      // Auth succeeded but no profile exists: the account was created directly
      // in the Firebase console without its matching `users` document.
      await _auth.signOut();
      throw const AuthException(
        'Your profile has not been set up yet. Contact your admin.',
      );
    }
    if (!user.isActive) {
      await _auth.signOut();
      throw const AuthException(
        'This account has been deactivated. Contact your admin.',
      );
    }
    return user;
  }

  /// Resolves the currently signed-in UID to its profile, or null when signed
  /// out. Called on boot, so it waits for Firebase Auth to restore its
  /// persisted session before deciding.
  Future<UserModel?> getCurrentUser() async {
    final uid = _auth.currentUser?.uid ?? (await authStateChanges().first)?.uid;
    if (uid == null) return null;
    try {
      final user = await _profileFor(uid);
      if (user == null || !user.isActive) return null;
      return user;
    } on FirebaseException {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } on FirebaseException catch (error) {
      throw AuthException(_networkMessage(error));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (error) {
      throw AuthException(_resetMessage(error));
    } on FirebaseException catch (error) {
      throw AuthException(_networkMessage(error));
    }
  }

  /// The signed-in user as a stream, so the app can react to a session ending
  /// elsewhere (token revoked, account disabled, sign-out on another device).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// The signed-in user's profile as a stream, re-resolved on every auth
  /// change. Emits null when signed out or when the profile is missing or
  /// deactivated.
  Stream<UserModel?> userChanges() async* {
    await for (final user in _auth.authStateChanges()) {
      if (user == null) {
        yield null;
        continue;
      }
      try {
        final profile = await _profileFor(user.uid);
        yield (profile == null || !profile.isActive) ? null : profile;
      } on FirebaseException {
        yield null;
      }
    }
  }

  /// Live view of one profile document, so a role change or deactivation lands
  /// in the app without a restart.
  Stream<UserModel?> watchProfile(String uid) {
    return _firestore.usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final user = userFromDoc(doc);
      return user.isActive ? user : null;
    });
  }

  Future<UserModel?> _profileFor(String uid) async {
    final doc = await _firestore.usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return userFromDoc(doc);
  }

  static String _signInMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'user-not-found' ||
      'invalid-email' =>
        'No account found for that email address.',
      // Firebase now returns a single opaque code for a bad email or password.
      'wrong-password' ||
      'invalid-credential' =>
        'Incorrect email or password. Please try again.',
      'user-disabled' =>
        'This account has been deactivated. Contact your admin.',
      'too-many-requests' =>
        'Too many attempts. Please wait a moment and try again.',
      'network-request-failed' =>
        'No internet connection. Check your network and try again.',
      _ => error.message ?? 'Sign-in failed. Please try again.',
    };
  }

  static String _resetMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'user-not-found' ||
      'invalid-email' =>
        'No account found for that email address.',
      'too-many-requests' =>
        'Too many attempts. Please wait a moment and try again.',
      'network-request-failed' =>
        'No internet connection. Check your network and try again.',
      _ => error.message ?? 'Could not send the reset email. Try again.',
    };
  }

  static String _networkMessage(FirebaseException error) {
    if (error.code == 'unavailable' || error.code == 'network-request-failed') {
      return 'No internet connection. Check your network and try again.';
    }
    return error.message ?? 'Something went wrong. Please try again.';
  }
}
