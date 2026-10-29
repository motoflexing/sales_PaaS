import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/shared_providers.dart';

/// Auth state: the signed-in user, or null when signed out.
class AuthNotifier extends StateNotifier<UserModel?> {
  AuthNotifier(this._repository) : super(null) {
    _restore();
    _watchSession();
  }

  final AuthRepository _repository;
  StreamSubscription<fb.User?>? _session;

  /// True until the persisted session has been read, so the router can hold on
  /// a splash instead of flashing the login screen on a warm start.
  bool _isBootstrapping = true;
  bool get isBootstrapping => _isBootstrapping;

  /// Emit on every assignment, including null-to-null, so the router's refresh
  /// listener fires when the bootstrap flag flips.
  @override
  bool updateShouldNotify(UserModel? old, UserModel? current) => true;

  Future<void> _restore() async {
    UserModel? restored;
    try {
      restored = await _repository.getCurrentUser();
    } finally {
      _isBootstrapping = false;
      if (mounted) state = restored;
    }
  }

  /// Firebase Auth owns the session, so it can end without the app asking:
  /// a disabled account, a revoked token, or a sign-out on another device. When
  /// that happens the state is cleared and the router sends the user to login.
  /// Sign-*in* events are ignored here — [login] already has the profile, and
  /// re-resolving it would cost a second Firestore read on every sign-in.
  void _watchSession() {
    _session = _repository.authStateChanges().listen((user) {
      if (user == null && !_isBootstrapping && mounted) {
        state = null;
      }
    });
  }

  @override
  void dispose() {
    _session?.cancel();
    super.dispose();
  }

  Future<void> login(String email, String password) async {
    state = await _repository.login(email, password);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = null;
  }

  Future<void> sendPasswordReset(String email) =>
      _repository.sendPasswordReset(email);
}

final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider);
});

final currentRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(authProvider)?.role;
});
