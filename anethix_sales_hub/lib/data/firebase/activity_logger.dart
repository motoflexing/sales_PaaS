import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity_model.dart';
import 'firestore_mappers.dart';
import 'firestore_refs.dart';

/// Writes timeline entries to the `activities` collection. This is the Firestore
/// replacement for `MockDatabase.logActivity`, including the display-name lookup
/// the mock did for free.
///
/// Activity writes are deliberately fire-and-forget from the caller's point of
/// view: a failed timeline entry must never fail the business write that
/// produced it (a logged call, a claimed lead). Failures are swallowed here.
class ActivityLogger {
  ActivityLogger(this._firestore);

  final FirebaseFirestore _firestore;

  /// Display names are read once per user per session. The timeline denormalises
  /// the name onto each activity, so this only costs one read per author.
  final Map<String, String> _nameCache = {};

  Future<String> nameOf(String? userId) async {
    if (userId == null || userId.isEmpty) return 'Unknown';
    final cached = _nameCache[userId];
    if (cached != null) return cached;
    try {
      final doc = await _firestore.usersRef.doc(userId).get();
      final name = doc.data()?['name'] as String?;
      final resolved = (name == null || name.trim().isEmpty) ? 'Unknown' : name;
      _nameCache[userId] = resolved;
      return resolved;
    } on Object {
      return 'Unknown';
    }
  }

  Future<void> log({
    required String userId,
    required String action,
    required String description,
    String? leadId,
    DateTime? at,
  }) async {
    try {
      final now = at ?? DateTime.now();
      await _firestore.activitiesRef.add(
        ActivityModel(
          id: '_',
          leadId: leadId,
          userId: userId,
          userName: await nameOf(userId),
          action: action,
          description: description,
          createdAt: now,
        ).toMap(),
      );
    } on Object {
      // A missing timeline entry is not worth failing the caller's write for.
    }
  }

  /// Queues an activity onto an existing batch, for writes that must land
  /// atomically with the record they describe.
  Future<void> logInBatch(
    WriteBatch batch, {
    required String userId,
    required String action,
    required String description,
    String? leadId,
    DateTime? at,
  }) async {
    batch.set(
      _firestore.activitiesRef.doc(),
      ActivityModel(
        id: '_',
        leadId: leadId,
        userId: userId,
        userName: await nameOf(userId),
        action: action,
        description: description,
        createdAt: at ?? DateTime.now(),
      ).toMap(),
    );
  }
}
