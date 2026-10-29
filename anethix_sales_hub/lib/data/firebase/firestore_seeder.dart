import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../shared/models/enums.dart';
import '../models/user_model.dart';
import 'firestore_mappers.dart';
import 'firestore_refs.dart';

/// One-time bootstrap for a fresh Firebase project.
///
/// ## Why this exists
///
/// Every account in this app is created by someone already signed in: an admin
/// creates managers, a manager's employees are created by the admin. That
/// leaves the very first admin with nobody to create it — a chicken-and-egg the
/// seeder breaks.
///
/// ## Step 1 — create the admin's Firebase Auth user MANUALLY
///
/// The Auth account CANNOT be created here. Creating a user from the client SDK
/// signs the caller in as that new user, and the security rules only let a
/// signed-in admin write the `users` collection — so a client-side "create the
/// first admin" would be both a session hijack and a rules violation. Create it
/// by hand, once:
///
///   1. Firebase console → Authentication → Sign-in method → enable
///      "Email/Password".
///   2. Authentication → Users → "Add user". Enter the admin's email and a
///      password. (Or from a trusted machine:
///      `firebase auth:import` / the Admin SDK's `createUser`.)
///   3. Copy the generated **User UID** — it is the document id the profile
///      must use, because every lookup in this app resolves a Firebase UID to a
///      `users` document of the same id.
///
/// ## Step 2 — seed the profile document
///
/// Sign in to the app as that admin (login will report "Your profile has not
/// been set up yet" — expected, the document does not exist yet), then call:
///
/// ```dart
/// await FirestoreSeeder().seedAdmin(
///   uid: '<the UID copied from the console>',
///   name: 'Ankit Dubey',
///   email: 'admin@anethix.com',   // must match the Auth account's email
///   phone: '9876543210',
/// );
/// ```
///
/// Run it once — from a temporary button, a `flutter run` one-off, or a debug
/// menu — then remove the call. [seedAdmin] is idempotent and will not
/// overwrite an existing profile, so a second run is harmless.
///
/// While the `users` collection is empty the rules cannot identify an admin, so
/// this first write needs the rules relaxed for the length of the seed. Publish
/// `firestore.rules` with the bootstrap clause noted in its header, seed, then
/// publish the locked-down version. Sign out and back in afterwards.
///
/// ## Step 3 — the admin creates the first manager IN THE APP
///
/// No seeding is needed past the admin. Signed in as admin:
///
///   1. Admin → Users → "Add user" (`/admin/users/create`).
///   2. Fill in name, email, phone, set **Role = Manager**, and choose a
///      temporary password; the manager can reset it from "Forgot password".
///   3. Save. `UserRepository.createUser` creates the Firebase Auth account and
///      the matching `users/{uid}` document together, so the manager can sign
///      in immediately.
///   4. Employees are created the same way with **Role = Employee**, and get a
///      **Manager** assigned on the same form — that `managerId` is what puts
///      them on a manager's team screens and leaderboard.
class FirestoreSeeder {
  FirestoreSeeder({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Creates the admin's `users` document. Returns the profile — the existing
  /// one if it was already seeded.
  ///
  /// [uid] must be the Firebase Auth UID from step 1. Pass nothing and the
  /// currently signed-in user's UID is used, which is the common case when you
  /// run this right after signing in as the admin.
  Future<UserModel> seedAdmin({
    String? uid,
    required String name,
    required String email,
    required String phone,
  }) async {
    final id = uid ?? _auth.currentUser?.uid;
    if (id == null || id.isEmpty) {
      throw StateError(
        'seedAdmin needs the admin\'s Firebase Auth UID. Create the Auth user '
        'in the Firebase console first (see the class docs), then pass its UID '
        'or sign in as that user before calling this.',
      );
    }

    final ref = _firestore.usersRef.doc(id);
    final existing = await ref.get();
    if (existing.exists) {
      debugPrint('Seeder: users/$id already exists, leaving it alone.');
      return userFromDoc(existing);
    }

    final now = DateTime.now();
    final admin = UserModel(
      id: id,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      role: UserRole.admin,
      isActive: true,
      joinDate: now,
      createdAt: now,
      updatedAt: now,
    );

    await ref.set(admin.toMap());
    debugPrint('Seeder: created admin profile users/$id.');
    return admin;
  }

  /// True when no profile exists yet — i.e. this project still needs seeding.
  /// Useful for gating a one-off debug affordance.
  Future<bool> needsSeeding() async {
    final snapshot = await _firestore.usersRef.limit(1).get();
    return snapshot.docs.isEmpty;
  }
}
