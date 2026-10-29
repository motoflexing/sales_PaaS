import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/activity_logger.dart';
import '../firebase/firestore_mappers.dart';
import '../firebase/firestore_refs.dart';
import '../models/activity_model.dart';

class ActivityRepositoryException implements Exception {
  const ActivityRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The timeline, in the `activities` collection. Writes go through
/// [ActivityLogger] from whichever repository produced the event; this class is
/// the read side plus a direct [addActivity] entry point.
class ActivityRepository {
  ActivityRepository({
    FirebaseFirestore? firestore,
    ActivityLogger? activityLogger,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _activity = activityLogger ??
            ActivityLogger(firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final ActivityLogger _activity;

  Future<List<ActivityModel>> getForLead(String leadId) async {
    final snapshot = await _guard(
      () => _firestore.activitiesRef
          .where('leadId', isEqualTo: leadId)
          .orderBy('createdAt', descending: true)
          .get(),
    );
    return List<ActivityModel>.unmodifiable(mapDocs(snapshot, activityFromDoc));
  }

  Future<List<ActivityModel>> getForUser(String userId, {int limit = 20}) async {
    final snapshot = await _guard(
      () => _firestore.activitiesRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(),
    );
    return List<ActivityModel>.unmodifiable(mapDocs(snapshot, activityFromDoc));
  }

  Future<List<ActivityModel>> getRecent({int limit = 20}) async {
    final snapshot = await _guard(
      () => _firestore.activitiesRef
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(),
    );
    return List<ActivityModel>.unmodifiable(mapDocs(snapshot, activityFromDoc));
  }

  Stream<List<ActivityModel>> watchForLead(String leadId) {
    return _firestore.activitiesRef
        .where('leadId', isEqualTo: leadId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => List<ActivityModel>.unmodifiable(
              mapDocs(snapshot, activityFromDoc),
            ));
  }

  Stream<List<ActivityModel>> watchForUser(String userId, {int limit = 20}) {
    return _firestore.activitiesRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => List<ActivityModel>.unmodifiable(
              mapDocs(snapshot, activityFromDoc),
            ));
  }

  /// Writes a timeline entry directly. The author's display name is resolved
  /// from the `users` collection when the caller left it blank.
  Future<ActivityModel> addActivity(ActivityModel activity) async {
    final doc = _firestore.activitiesRef.doc();
    final userName = activity.userName.trim().isEmpty
        ? await _activity.nameOf(activity.userId)
        : activity.userName;
    final stored = activity.copyWith(id: doc.id, userName: userName);
    await _guard(() => doc.set(stored.toMap()));
    return stored;
  }

  /// Alias for [getForLead] under the backend contract's name.
  Future<List<ActivityModel>> getActivitiesByLead(String leadId) =>
      getForLead(leadId);

  /// Alias for [getForUser] under the backend contract's name.
  Future<List<ActivityModel>> getActivitiesByUser(
    String userId, {
    int limit = 20,
  }) =>
      getForUser(userId, limit: limit);

  static String _message(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'You do not have permission to view that activity.',
      'unavailable' || 'network-request-failed' =>
        'No internet connection. Check your network and try again.',
      _ => error.message ?? 'Something went wrong. Please try again.',
    };
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FirebaseException catch (error) {
      throw ActivityRepositoryException(_message(error));
    }
  }
}
