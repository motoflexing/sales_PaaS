import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/enums.dart';
import '../firebase/activity_logger.dart';
import '../firebase/firestore_mappers.dart';
import '../firebase/firestore_refs.dart';
import '../models/activity_model.dart';
import '../models/follow_up_model.dart';

class FollowUpRepositoryException implements Exception {
  const FollowUpRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Follow-ups in the `followUps` collection.
class FollowUpRepository {
  FollowUpRepository({
    FirebaseFirestore? firestore,
    ActivityLogger? activityLogger,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _activity = activityLogger ??
            ActivityLogger(firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final ActivityLogger _activity;

  /// Firestore caps a batch at 500 writes.
  static const int _batchLimit = 400;

  // ------------------------------- Reads -------------------------------

  Future<List<FollowUpModel>> getByEmployee(String employeeId) async {
    final snapshot = await _guard(
      () => _firestore.followUpsRef
          .where('employeeId', isEqualTo: employeeId)
          .get(),
    );
    return _reconcileAndSort(snapshot);
  }

  /// A manager's whole team. Firestore's `whereIn` takes at most 30 values, so
  /// larger teams are fetched in chunks and merged.
  Future<List<FollowUpModel>> getByEmployees(List<String> employeeIds) async {
    if (employeeIds.isEmpty) return const [];

    final results = <FollowUpModel>[];
    final overdue = <String>[];
    for (final chunk in _chunk(employeeIds.toSet().toList(), 30)) {
      final snapshot = await _guard(
        () => _firestore.followUpsRef.where('employeeId', whereIn: chunk).get(),
      );
      final parsed = mapDocs(snapshot, followUpFromDoc);
      results.addAll(_promoteOverdue(parsed, overdue));
    }
    await _persistOverdue(overdue);

    results.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return List<FollowUpModel>.unmodifiable(results);
  }

  Future<List<FollowUpModel>> getAll() async {
    final snapshot = await _guard(() => _firestore.followUpsRef.get());
    return _reconcileAndSort(snapshot);
  }

  Future<List<FollowUpModel>> getByLead(String leadId) async {
    final snapshot = await _guard(
      () => _firestore.followUpsRef.where('leadId', isEqualTo: leadId).get(),
    );
    final list = await _reconcileAndSort(snapshot);
    final descending = list.toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return List<FollowUpModel>.unmodifiable(descending);
  }

  // ------------------------- Real-time streams -------------------------

  /// One employee's follow-ups, live. Overdue promotion still runs on each
  /// emission, and because the promotion is itself a Firestore write the
  /// stream re-emits with the corrected statuses.
  Stream<List<FollowUpModel>> watchByEmployee(String employeeId) {
    return _firestore.followUpsRef
        .where('employeeId', isEqualTo: employeeId)
        .snapshots()
        .asyncMap((snapshot) => _reconcileAndSort(snapshot));
  }

  Stream<List<FollowUpModel>> watchByLead(String leadId) {
    return _firestore.followUpsRef
        .where('leadId', isEqualTo: leadId)
        .snapshots()
        .asyncMap((snapshot) => _reconcileAndSort(snapshot));
  }

  // ------------------------------- Writes -------------------------------

  Future<FollowUpModel> schedule({
    required String leadId,
    required String employeeId,
    required DateTime scheduledAt,
    String? remark,
  }) async {
    if (scheduledAt.isBefore(DateTime.now())) {
      throw const FollowUpRepositoryException(
        'Pick a follow-up time in the future.',
      );
    }

    final now = DateTime.now();
    final doc = _firestore.followUpsRef.doc();
    final followUp = FollowUpModel(
      id: doc.id,
      leadId: leadId,
      employeeId: employeeId,
      scheduledAt: scheduledAt,
      status: FollowUpStatus.pending,
      remark: (remark?.trim().isEmpty ?? true) ? null : remark!.trim(),
      createdAt: now,
    );

    await _guard(() => doc.set(followUp.toMap()));
    await _touchLead(leadId, now);
    await _activity.log(
      userId: employeeId,
      leadId: leadId,
      action: ActivityAction.followUpScheduled,
      description: 'Scheduled a follow-up',
      at: now,
    );
    return followUp;
  }

  Future<FollowUpModel> complete(String followUpId, {String? remark}) async {
    final followUp = await _lookup(followUpId);
    if (followUp.status == FollowUpStatus.completed) {
      throw const FollowUpRepositoryException(
        'That follow-up is already completed.',
      );
    }

    final now = DateTime.now();
    final resolvedRemark =
        (remark?.trim().isEmpty ?? true) ? followUp.remark : remark!.trim();

    await _guard(
      () => _firestore.followUpsRef.doc(followUpId).update({
        'status': FollowUpStatus.completed.name,
        'completedAt': writeTimestamp(now),
        'remark': resolvedRemark,
      }),
    );
    await _touchLead(followUp.leadId, now);
    await _activity.log(
      userId: followUp.employeeId,
      leadId: followUp.leadId,
      action: ActivityAction.followUpCompleted,
      description: 'Completed a follow-up',
      at: now,
    );

    return followUp.copyWith(
      status: FollowUpStatus.completed,
      completedAt: now,
      remark: resolvedRemark,
    );
  }

  Future<FollowUpModel> reschedule(
    String followUpId,
    DateTime scheduledAt,
  ) async {
    if (scheduledAt.isBefore(DateTime.now())) {
      throw const FollowUpRepositoryException(
        'Pick a follow-up time in the future.',
      );
    }
    final followUp = await _lookup(followUpId);

    await _guard(
      () => _firestore.followUpsRef.doc(followUpId).update({
        'scheduledAt': writeTimestamp(scheduledAt),
        'status': FollowUpStatus.rescheduled.name,
      }),
    );
    await _activity.log(
      userId: followUp.employeeId,
      leadId: followUp.leadId,
      action: ActivityAction.followUpRescheduled,
      description: 'Rescheduled a follow-up',
    );

    return followUp.copyWith(
      scheduledAt: scheduledAt,
      status: FollowUpStatus.rescheduled,
    );
  }

  Future<void> deleteFollowUp(String followUpId) async {
    await _guard(() => _firestore.followUpsRef.doc(followUpId).delete());
  }

  // ------------------------------- Helpers -------------------------------

  Future<FollowUpModel> _lookup(String id) async {
    final doc = await _guard(() => _firestore.followUpsRef.doc(id).get());
    if (!doc.exists) {
      throw const FollowUpRepositoryException(
        'That follow-up no longer exists.',
      );
    }
    return followUpFromDoc(doc);
  }

  /// Anything still pending whose slot has passed is promoted to overdue on
  /// read, so the tabs never show a stale "pending" for yesterday. The
  /// promotion is written back in a batch, which is what keeps a second device
  /// (and any server-side reporting) seeing the same status.
  Future<List<FollowUpModel>> _reconcileAndSort(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final overdue = <String>[];
    final list = _promoteOverdue(mapDocs(snapshot, followUpFromDoc), overdue)
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    await _persistOverdue(overdue);
    return List<FollowUpModel>.unmodifiable(list);
  }

  /// Returns the list with lapsed follow-ups shown as overdue, collecting the
  /// ids that need the same change written back to Firestore.
  static List<FollowUpModel> _promoteOverdue(
    List<FollowUpModel> source,
    List<String> collectIds,
  ) {
    final now = DateTime.now();
    final out = <FollowUpModel>[];
    for (final followUp in source) {
      final hasLapsed = (followUp.status == FollowUpStatus.pending ||
              followUp.status == FollowUpStatus.rescheduled) &&
          followUp.scheduledAt.isBefore(now);
      if (hasLapsed) {
        collectIds.add(followUp.id);
        out.add(followUp.copyWith(status: FollowUpStatus.overdue));
      } else {
        out.add(followUp);
      }
    }
    return out;
  }

  Future<void> _persistOverdue(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      for (final chunk in _chunk(ids, _batchLimit)) {
        final batch = _firestore.batch();
        for (final id in chunk) {
          batch.update(_firestore.followUpsRef.doc(id), {
            'status': FollowUpStatus.overdue.name,
          });
        }
        await batch.commit();
      }
    } on FirebaseException {
      // The caller already sees the corrected statuses; a failed write-back
      // just means the next read tries again. Not worth failing a read for —
      // notably, a manager can read their team's follow-ups but not write them.
    }
  }

  Future<void> _touchLead(String leadId, DateTime at) async {
    try {
      await _firestore.leadsRef.doc(leadId).update({
        'updatedAt': writeTimestamp(at),
        'lastActivityAt': writeTimestamp(at),
      });
    } on FirebaseException {
      // Not fatal; the follow-up itself is written.
    }
  }

  static Iterable<List<T>> _chunk<T>(List<T> source, int size) sync* {
    for (var i = 0; i < source.length; i += size) {
      yield source.sublist(i, i + size > source.length ? source.length : i + size);
    }
  }

  static String _message(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'You do not have permission to perform that action.',
      'not-found' => 'That follow-up no longer exists.',
      'unavailable' || 'network-request-failed' =>
        'No internet connection. Check your network and try again.',
      _ => error.message ?? 'Something went wrong. Please try again.',
    };
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FirebaseException catch (error) {
      throw FollowUpRepositoryException(_message(error));
    }
  }
}
