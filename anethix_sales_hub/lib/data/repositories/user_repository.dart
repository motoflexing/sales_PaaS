import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../../shared/models/enums.dart';
import '../firebase/activity_logger.dart';
import '../firebase/firestore_mappers.dart';
import '../firebase/firestore_refs.dart';
import '../models/activity_model.dart';
import '../models/user_model.dart';

class UserRepositoryException implements Exception {
  const UserRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Profiles live in the `users` collection keyed by Firebase Auth UID.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore, ActivityLogger? activityLogger})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _activity =
            activityLogger ?? ActivityLogger(firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final ActivityLogger _activity;

  /// Name of the throwaway secondary Firebase app used for provisioning. See
  /// [createUser] for why it exists.
  static const String _provisioningAppName = 'anethix-user-provisioning';

  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _guard(() => _firestore.usersRef.get());
    final users = mapDocs(snapshot, userFromDoc)
      ..sort((a, b) => a.name.compareTo(b.name));
    return List<UserModel>.unmodifiable(users);
  }

  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    final snapshot = await _guard(
      () => _firestore.usersRef.where('role', isEqualTo: role.name).get(),
    );
    final users = mapDocs(snapshot, userFromDoc)
      ..sort((a, b) => a.name.compareTo(b.name));
    return List<UserModel>.unmodifiable(users);
  }

  /// The employees reporting to one manager.
  Future<List<UserModel>> getTeamMembers(String managerId) async {
    final snapshot = await _guard(
      () => _firestore.usersRef
          .where('role', isEqualTo: UserRole.employee.name)
          .where('managerId', isEqualTo: managerId)
          .get(),
    );
    final users = mapDocs(snapshot, userFromDoc)
      ..sort((a, b) => a.name.compareTo(b.name));
    return List<UserModel>.unmodifiable(users);
  }

  /// Alias for [getTeamMembers], matching the backend contract's naming.
  Future<List<UserModel>> getUsersByManager(String managerId) =>
      getTeamMembers(managerId);

  Future<List<UserModel>> getActiveManagers() async {
    final snapshot = await _guard(
      () => _firestore.usersRef
          .where('role', isEqualTo: UserRole.manager.name)
          .where('isActive', isEqualTo: true)
          .get(),
    );
    final users = mapDocs(snapshot, userFromDoc)
      ..sort((a, b) => a.name.compareTo(b.name));
    return List<UserModel>.unmodifiable(users);
  }

  Future<UserModel> getUserById(String id) async {
    final doc = await _guard(() => _firestore.usersRef.doc(id).get());
    if (!doc.exists) {
      throw const UserRepositoryException('That user no longer exists.');
    }
    return userFromDoc(doc);
  }

  /// Live user list, for screens that should reflect a new hire immediately.
  Stream<List<UserModel>> watchAllUsers() {
    return _firestore.usersRef.snapshots().map((snapshot) {
      final users = mapDocs(snapshot, userFromDoc)
        ..sort((a, b) => a.name.compareTo(b.name));
      return List<UserModel>.unmodifiable(users);
    });
  }

  /// Creates the Firebase Auth account and its `users` document together.
  ///
  /// The Auth account is created through a *secondary* Firebase app instance.
  /// `createUserWithEmailAndPassword` on the default instance signs the caller
  /// in as the account it just created, which would kick the admin out of their
  /// own session mid-flow. The secondary app has its own auth state, so the
  /// admin's session on the default app is untouched; the throwaway app is
  /// disposed on the way out.
  ///
  /// If the Auth account is created but the Firestore write then fails, the
  /// orphaned Auth account is deleted so the email is not left unusable.
  Future<UserModel> createUser({
    required String name,
    required String email,
    required String phone,
    required UserRole role,
    required String password,
    required String createdByUserId,
    String? managerId,
  }) async {
    final normalised = email.trim().toLowerCase();

    final existing = await _guard(
      () => _firestore.usersRef
          .where('email', isEqualTo: normalised)
          .limit(1)
          .get(),
    );
    if (existing.docs.isNotEmpty) {
      throw const UserRepositoryException(
        'An account with that email already exists.',
      );
    }

    FirebaseApp? provisioningApp;
    User? createdAuthUser;
    try {
      provisioningApp = await Firebase.initializeApp(
        name: _provisioningAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final provisioningAuth = FirebaseAuth.instanceFor(app: provisioningApp);
      final credential = await provisioningAuth.createUserWithEmailAndPassword(
        email: normalised,
        password: password,
      );
      createdAuthUser = credential.user;
      final uid = createdAuthUser?.uid;
      if (uid == null) {
        throw const UserRepositoryException(
          'Could not create that account. Please try again.',
        );
      }

      final now = DateTime.now();
      final user = UserModel(
        id: uid,
        name: name.trim(),
        email: normalised,
        phone: phone.trim(),
        role: role,
        managerId: role == UserRole.employee ? managerId : null,
        isActive: true,
        joinDate: now,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.usersRef.doc(uid).set(user.toMap());
      await provisioningAuth.signOut();

      await _activity.log(
        userId: createdByUserId,
        action: ActivityAction.userCreated,
        description:
            'Created ${role.label.toLowerCase()} account for ${user.name}',
        at: now,
      );
      return user;
    } on FirebaseAuthException catch (error) {
      throw UserRepositoryException(_createAuthMessage(error));
    } on FirebaseException catch (error) {
      // The Auth account exists but the profile write failed. Roll it back so
      // the email can be reused on the next attempt.
      await _deleteQuietly(createdAuthUser);
      throw UserRepositoryException(_message(error));
    } finally {
      if (provisioningApp != null) {
        await provisioningApp.delete();
      }
    }
  }

  Future<UserModel> setActive(String userId, bool isActive) async {
    final user = await getUserById(userId);
    final now = DateTime.now();
    await _guard(
      () => _firestore.usersRef.doc(userId).update({
        'isActive': isActive,
        'updatedAt': writeTimestamp(now),
      }),
    );
    return user.copyWith(isActive: isActive, updatedAt: now);
  }

  /// Alias for `setActive(id, false)`, matching the backend contract's naming.
  Future<UserModel> deactivateUser(String userId) => setActive(userId, false);

  Future<UserModel> assignManager(String employeeId, String? managerId) async {
    final user = await getUserById(employeeId);
    if (user.role != UserRole.employee) {
      throw const UserRepositoryException(
        'Only employees can be assigned to a manager.',
      );
    }
    final now = DateTime.now();
    await _guard(
      () => _firestore.usersRef.doc(employeeId).update({
        'managerId': managerId,
        'updatedAt': writeTimestamp(now),
      }),
    );
    return user.copyWith(managerId: managerId, updatedAt: now);
  }

  Future<UserModel> updateUser({
    required String userId,
    String? name,
    String? phone,
  }) async {
    final user = await getUserById(userId);
    final now = DateTime.now();
    final updates = <String, dynamic>{'updatedAt': writeTimestamp(now)};
    if (name != null) updates['name'] = name.trim();
    if (phone != null) updates['phone'] = phone.trim();

    await _guard(() => _firestore.usersRef.doc(userId).update(updates));
    return user.copyWith(
      name: name?.trim(),
      phone: phone?.trim(),
      updatedAt: now,
    );
  }

  static Future<void> _deleteQuietly(User? user) async {
    if (user == null) return;
    try {
      await user.delete();
    } on Object {
      // Best-effort cleanup only.
    }
  }

  static String _createAuthMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => 'An account with that email already exists.',
      'invalid-email' => 'That email address is not valid.',
      'weak-password' => 'Choose a stronger password (at least 6 characters).',
      'operation-not-allowed' =>
        'Email sign-in is disabled for this project. Enable it in Firebase.',
      'network-request-failed' =>
        'No internet connection. Check your network and try again.',
      _ => error.message ?? 'Could not create that account. Please try again.',
    };
  }

  static String _message(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'You do not have permission to perform that action.',
      'unavailable' || 'network-request-failed' =>
        'No internet connection. Check your network and try again.',
      _ => error.message ?? 'Something went wrong. Please try again.',
    };
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FirebaseException catch (error) {
      throw UserRepositoryException(_message(error));
    }
  }
}
