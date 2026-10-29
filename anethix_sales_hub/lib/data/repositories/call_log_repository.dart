import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/enums.dart';
import '../firebase/activity_logger.dart';
import '../firebase/firestore_mappers.dart';
import '../firebase/firestore_refs.dart';
import '../models/activity_model.dart';
import '../models/call_log_model.dart';
import '../models/follow_up_model.dart';
import '../models/remark_model.dart';

class CallLogRepositoryException implements Exception {
  const CallLogRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Call history in the `callLogs` collection.
class CallLogRepository {
  CallLogRepository({
    FirebaseFirestore? firestore,
    ActivityLogger? activityLogger,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _activity = activityLogger ??
            ActivityLogger(firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final ActivityLogger _activity;

  Future<List<CallLogModel>> getByLead(String leadId) async {
    final snapshot = await _guard(
      () => _firestore.callLogsRef
          .where('leadId', isEqualTo: leadId)
          .orderBy('createdAt', descending: true)
          .get(),
    );
    return _sorted(mapDocs(snapshot, callLogFromDoc));
  }

  Future<List<CallLogModel>> getByEmployee(String employeeId) async {
    final snapshot = await _guard(
      () => _firestore.callLogsRef
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('createdAt', descending: true)
          .get(),
    );
    return _sorted(mapDocs(snapshot, callLogFromDoc));
  }

  Future<List<CallLogModel>> getAll() async {
    final snapshot = await _guard(
      () => _firestore.callLogsRef.orderBy('createdAt', descending: true).get(),
    );
    return _sorted(mapDocs(snapshot, callLogFromDoc));
  }

  Stream<List<CallLogModel>> watchByLead(String leadId) {
    return _firestore.callLogsRef
        .where('leadId', isEqualTo: leadId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => _sorted(mapDocs(snapshot, callLogFromDoc)));
  }

  Stream<List<CallLogModel>> watchByEmployee(String employeeId) {
    return _firestore.callLogsRef
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => _sorted(mapDocs(snapshot, callLogFromDoc)));
  }

  /// Adds a raw call document. [logCall] is the richer entry point that also
  /// writes the remark, follow-up and status bump a call produces.
  Future<CallLogModel> addCallLog(CallLogModel callLog) async {
    final doc = _firestore.callLogsRef.doc();
    final stored = callLog.copyWith(id: doc.id);
    await _guard(() => doc.set(stored.toMap()));
    return stored;
  }

  /// Records a call and, in one go, the remark it produced, an optional
  /// follow-up, and the first-call status bump to CONTACTED.
  ///
  /// The call, remark and follow-up go into a single batch so a partial failure
  /// cannot leave a follow-up with no call behind it. The lead's status bump is
  /// a separate write because an employee's permission to update the lead is
  /// narrower than their permission to log their own call.
  Future<CallLogModel> logCall({
    required String leadId,
    required String employeeId,
    required CallOutcome outcome,
    String? remark,
    DateTime? followUpDate,
  }) async {
    final now = DateTime.now();
    final trimmedRemark =
        (remark?.trim().isEmpty ?? true) ? null : remark!.trim();

    final isFirstCall = await _isFirstCallFor(leadId);
    final batch = _firestore.batch();

    final callDoc = _firestore.callLogsRef.doc();
    final call = CallLogModel(
      id: callDoc.id,
      leadId: leadId,
      employeeId: employeeId,
      date: now,
      outcome: outcome,
      remark: trimmedRemark,
      followUpDate: followUpDate,
      createdAt: now,
    );
    batch.set(callDoc, call.toMap());
    await _activity.logInBatch(
      batch,
      userId: employeeId,
      leadId: leadId,
      action: ActivityAction.callLogged,
      description: 'Logged a call - ${outcome.label}',
      at: now,
    );

    if (trimmedRemark != null) {
      batch.set(
        _firestore.remarksRef.doc(),
        RemarkModel(
          id: '_',
          leadId: leadId,
          authorId: employeeId,
          authorName: await _activity.nameOf(employeeId),
          text: trimmedRemark,
          createdAt: now,
        ).toMap(),
      );
      await _activity.logInBatch(
        batch,
        userId: employeeId,
        leadId: leadId,
        action: ActivityAction.remarkAdded,
        description: 'Added a remark',
        at: now,
      );
    }

    if (followUpDate != null) {
      batch.set(
        _firestore.followUpsRef.doc(),
        FollowUpModel(
          id: '_',
          leadId: leadId,
          employeeId: employeeId,
          scheduledAt: followUpDate,
          status: FollowUpStatus.pending,
          remark: trimmedRemark,
          createdAt: now,
        ).toMap(),
      );
      await _activity.logInBatch(
        batch,
        userId: employeeId,
        leadId: leadId,
        action: ActivityAction.followUpScheduled,
        description: 'Scheduled a follow-up',
        at: now,
      );
    }

    await _guard(batch.commit);
    await _bumpLead(
      leadId: leadId,
      employeeId: employeeId,
      isFirstCall: isFirstCall,
      at: now,
    );
    return call;
  }

  /// The first conversation is what moves a claimed lead to contacted.
  Future<void> _bumpLead({
    required String leadId,
    required String employeeId,
    required bool isFirstCall,
    required DateTime at,
  }) async {
    try {
      final leadRef = _firestore.leadsRef.doc(leadId);
      final snapshot = await leadRef.get();
      if (!snapshot.exists) return;

      final status = snapshot.data()?['status'] as String?;
      final shouldPromote = isFirstCall && status == LeadStatus.claimed.name;

      await leadRef.update({
        if (shouldPromote) 'status': LeadStatus.contacted.name,
        'updatedAt': writeTimestamp(at),
        'lastActivityAt': writeTimestamp(at),
      });

      if (shouldPromote) {
        await _activity.log(
          userId: employeeId,
          leadId: leadId,
          action: ActivityAction.statusChanged,
          description: 'Moved the lead from Claimed to Contacted',
          at: at,
        );
      }
    } on FirebaseException {
      // The call itself is already recorded; a missed status bump is
      // recoverable from the lead screen.
    }
  }

  Future<bool> _isFirstCallFor(String leadId) async {
    try {
      final existing = await _firestore.callLogsRef
          .where('leadId', isEqualTo: leadId)
          .limit(1)
          .get();
      return existing.docs.isEmpty;
    } on FirebaseException {
      return false;
    }
  }

  static List<CallLogModel> _sorted(Iterable<CallLogModel> source) {
    final list = source.toList()..sort((a, b) => b.date.compareTo(a.date));
    return List<CallLogModel>.unmodifiable(list);
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
      throw CallLogRepositoryException(_message(error));
    }
  }
}
