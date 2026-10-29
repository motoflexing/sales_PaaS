import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firebase/activity_logger.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/call_log_repository.dart';
import '../../data/repositories/follow_up_repository.dart';
import '../../data/repositories/lead_repository.dart';
import '../../data/repositories/leaderboard_repository.dart';
import '../../data/repositories/user_repository.dart';

/// The Firebase handles, provided rather than reached for statically, so tests
/// can override them with fakes at the root of the tree.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// One logger across every repository, so the display-name cache is shared
/// instead of each repository paying for its own lookups.
final activityLoggerProvider = Provider<ActivityLogger>((ref) {
  return ActivityLogger(ref.watch(firestoreProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    firestore: ref.watch(firestoreProvider),
    activityLogger: ref.watch(activityLoggerProvider),
  );
});

final leadRepositoryProvider = Provider<LeadRepository>((ref) {
  return LeadRepository(
    firestore: ref.watch(firestoreProvider),
    activityLogger: ref.watch(activityLoggerProvider),
  );
});

final callLogRepositoryProvider = Provider<CallLogRepository>((ref) {
  return CallLogRepository(
    firestore: ref.watch(firestoreProvider),
    activityLogger: ref.watch(activityLoggerProvider),
  );
});

final followUpRepositoryProvider = Provider<FollowUpRepository>((ref) {
  return FollowUpRepository(
    firestore: ref.watch(firestoreProvider),
    activityLogger: ref.watch(activityLoggerProvider),
  );
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(
    firestore: ref.watch(firestoreProvider),
    activityLogger: ref.watch(activityLoggerProvider),
  );
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepository(firestore: ref.watch(firestoreProvider));
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(
    firestore: ref.watch(firestoreProvider),
    activityLogger: ref.watch(activityLoggerProvider),
  );
});

/// Bumped after any write that other screens should re-read.
///
/// The lists that matter most — the live board, an employee's own leads, their
/// follow-ups — are now driven by Firestore `snapshots()` and update on their
/// own. This revision counter still exists for the aggregate dashboards, which
/// are one-shot reads across several collections and have no single stream to
/// listen to.
final dataRevisionProvider = StateProvider<int>((ref) => 0);

extension DataRevisionX on Ref {
  void bumpDataRevision() =>
      read(dataRevisionProvider.notifier).update((value) => value + 1);
}

extension WidgetRefDataRevisionX on WidgetRef {
  void bumpDataRevision() =>
      read(dataRevisionProvider.notifier).update((value) => value + 1);
}
