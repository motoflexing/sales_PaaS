import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/activity_logger.dart';
import '../firebase/firestore_mappers.dart';
import '../firebase/firestore_refs.dart';
import '../models/activity_model.dart';
import '../models/attendance_model.dart';

class AttendanceException implements Exception {
  const AttendanceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when an employee tries to check in twice on the same calendar day.
class DuplicateCheckInException extends AttendanceException {
  const DuplicateCheckInException([
    super.message = 'You have already checked in today.',
  ]);
}

/// Attendance in the `attendance` collection.
///
/// Each document carries a `dateKey` (`2026-09-05`) alongside its `date`
/// timestamp, so "has this employee already checked in today" is one equality
/// query rather than a timestamp range scan.
class AttendanceRepository {
  AttendanceRepository({
    FirebaseFirestore? firestore,
    ActivityLogger? activityLogger,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _activity = activityLogger ??
            ActivityLogger(firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final ActivityLogger _activity;

  Future<AttendanceModel?> getToday(String employeeId) =>
      _todayRecord(employeeId);

  Future<List<AttendanceModel>> getHistory(
    String employeeId, {
    int days = 30,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final snapshot = await _guard(
      () => _firestore.attendanceRef
          .where('employeeId', isEqualTo: employeeId)
          .where('date', isGreaterThan: writeTimestamp(cutoff))
          .orderBy('date', descending: true)
          .get(),
    );
    return List<AttendanceModel>.unmodifiable(
      mapDocs(snapshot, attendanceFromDoc),
    );
  }

  /// Everyone's record for one calendar day, for the manager and admin boards.
  Future<List<AttendanceModel>> getForDate(DateTime date) async {
    final snapshot = await _guard(
      () => _firestore.attendanceRef
          .where('dateKey', isEqualTo: attendanceDateKey(date))
          .get(),
    );
    return List<AttendanceModel>.unmodifiable(
      mapDocs(snapshot, attendanceFromDoc),
    );
  }

  /// Alias for [getHistory] under the backend contract's name.
  Future<List<AttendanceModel>> getAttendanceByEmployee(String employeeId) =>
      getHistory(employeeId);

  Stream<AttendanceModel?> watchToday(String employeeId) {
    return _firestore.attendanceRef
        .where('employeeId', isEqualTo: employeeId)
        .where('dateKey', isEqualTo: attendanceDateKey(DateTime.now()))
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isEmpty
            ? null
            : attendanceFromDoc(snapshot.docs.first));
  }

  Stream<List<AttendanceModel>> watchByEmployee(String employeeId) {
    return _firestore.attendanceRef
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => List<AttendanceModel>.unmodifiable(
              mapDocs(snapshot, attendanceFromDoc),
            ));
  }

  Future<AttendanceModel> checkIn(String employeeId) async {
    if (await _todayRecord(employeeId) != null) {
      throw const DuplicateCheckInException();
    }

    final now = DateTime.now();
    final doc = _firestore.attendanceRef.doc();
    final record = AttendanceModel(
      id: doc.id,
      employeeId: employeeId,
      date: DateTime(now.year, now.month, now.day),
      checkIn: now,
    );

    await _guard(() => doc.set(record.toMap()));
    await _activity.log(
      userId: employeeId,
      action: ActivityAction.checkedIn,
      description: 'Checked in for the day',
      at: now,
    );
    return record;
  }

  Future<AttendanceModel> checkOut(String employeeId) async {
    final record = await _todayRecord(employeeId);
    if (record == null) {
      throw const AttendanceException(
        'You need to check in before checking out.',
      );
    }
    if (record.checkOut != null) {
      throw const AttendanceException('You have already checked out today.');
    }

    final now = DateTime.now();
    final workingHours = now.difference(record.checkIn).inMinutes / 60.0;

    await _guard(
      () => _firestore.attendanceRef.doc(record.id).update({
        'checkOut': writeTimestamp(now),
        'workingHours': workingHours,
      }),
    );
    await _activity.log(
      userId: employeeId,
      action: ActivityAction.checkedOut,
      description: 'Checked out after ${workingHours.toStringAsFixed(1)} hours',
      at: now,
    );
    return record.copyWith(checkOut: now, workingHours: workingHours);
  }

  Future<AttendanceModel?> _todayRecord(String employeeId) async {
    final snapshot = await _guard(
      () => _firestore.attendanceRef
          .where('employeeId', isEqualTo: employeeId)
          .where('dateKey', isEqualTo: attendanceDateKey(DateTime.now()))
          .limit(1)
          .get(),
    );
    if (snapshot.docs.isEmpty) return null;
    return attendanceFromDoc(snapshot.docs.first);
  }

  static String _message(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'You can only record your own attendance.',
      'unavailable' || 'network-request-failed' =>
        'No internet connection. Check your network and try again.',
      _ => error.message ?? 'Something went wrong. Please try again.',
    };
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FirebaseException catch (error) {
      throw AttendanceException(_message(error));
    }
  }
}
