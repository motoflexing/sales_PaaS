import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/scoring_rules.dart';
import '../../shared/models/enums.dart';
import '../firebase/firestore_mappers.dart';
import '../firebase/firestore_refs.dart';
import '../models/call_log_model.dart';
import '../models/follow_up_model.dart';
import '../models/lead_model.dart';
import '../models/leaderboard_entry.dart';
import '../models/user_model.dart';

class LeaderboardRepositoryException implements Exception {
  const LeaderboardRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Scores are computed from the raw Firestore records — call logs, follow-ups
/// and leads — rather than read from a stored total. A stored score can drift
/// from the records that produced it, and it is also the one field nobody
/// should be able to write: the security rules make `leaderboard` read-only for
/// clients, reserved as a cache for a future Cloud Function.
class LeaderboardRepository {
  LeaderboardRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Firestore's `whereIn` accepts at most 30 values per query.
  static const int _whereInLimit = 30;

  /// Inclusive lower bound for a period; null means "no lower bound".
  static DateTime? periodStart(LeaderboardPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      LeaderboardPeriod.today => today,
      LeaderboardPeriod.thisWeek =>
        today.subtract(Duration(days: today.weekday - 1)),
      LeaderboardPeriod.thisMonth => DateTime(now.year, now.month),
      LeaderboardPeriod.thisQuarter =>
        DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1),
      LeaderboardPeriod.allTime => null,
    };
  }

  Future<List<LeaderboardEntry>> getLeaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.thisMonth,
    String? managerId,
  }) async {
    final start = periodStart(period);
    final employees = await _employees(managerId);
    if (employees.isEmpty) return const [];

    final ids = employees.map((e) => e.id).toList();

    // Three grouped queries rather than three per employee: each collection is
    // fetched in `whereIn` chunks and bucketed by employee in memory.
    final leadsByEmployee = await _leadsByEmployee(ids);
    final callsByEmployee = await _callsByEmployee(ids, start);
    final followUpsByEmployee = await _completedFollowUpsByEmployee(ids, start);

    bool inPeriod(DateTime? at) =>
        at != null && (start == null || !at.isBefore(start));

    final entries = <LeaderboardEntry>[];
    for (final employee in employees) {
      final leads = leadsByEmployee[employee.id] ?? const <LeadModel>[];
      final calls = callsByEmployee[employee.id] ?? const <CallLogModel>[];
      final followUps =
          followUpsByEmployee[employee.id] ?? const <FollowUpModel>[];

      final leadsTaken = leads.where((l) => inPeriod(l.claimedAt)).length;
      final connectedCalls = calls.where((c) => c.outcome.isConnected).length;

      final meetings = leads
          .where((l) =>
              (l.status == LeadStatus.meeting ||
                  l.status == LeadStatus.proposal ||
                  l.status == LeadStatus.won) &&
              inPeriod(l.updatedAt))
          .length;

      final won = leads
          .where((l) => l.status == LeadStatus.won && inPeriod(l.updatedAt))
          .length;

      entries.add(
        LeaderboardEntry(
          employeeId: employee.id,
          employeeName: employee.name,
          leadsTaken: leadsTaken,
          callsMade: calls.length,
          followUpsCompleted: followUps.length,
          meetings: meetings,
          won: won,
          score: ScoringRules.total(
            leadsTaken: leadsTaken,
            connectedCalls: connectedCalls,
            completedFollowUps: followUps.length,
            meetings: meetings,
            won: won,
          ),
        ),
      );
    }

    entries.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.employeeName.compareTo(b.employeeName);
    });

    return List<LeaderboardEntry>.unmodifiable([
      for (var i = 0; i < entries.length; i++) entries[i].copyWith(rank: i + 1),
    ]);
  }

  Future<LeaderboardEntry?> getEntryFor(
    String employeeId, {
    LeaderboardPeriod period = LeaderboardPeriod.thisMonth,
  }) async {
    final board = await getLeaderboard(period: period);
    for (final entry in board) {
      if (entry.employeeId == employeeId) return entry;
    }
    return null;
  }

  // ------------------------------- Queries -------------------------------

  Future<List<UserModel>> _employees(String? managerId) async {
    var query = _firestore.usersRef
        .where('role', isEqualTo: UserRole.employee.name)
        .where('isActive', isEqualTo: true);
    if (managerId != null) {
      query = query.where('managerId', isEqualTo: managerId);
    }
    final snapshot = await _guard(() => query.get());
    return mapDocs(snapshot, userFromDoc);
  }

  Future<Map<String, List<LeadModel>>> _leadsByEmployee(
    List<String> employeeIds,
  ) async {
    final grouped = <String, List<LeadModel>>{};
    for (final chunk in _chunk(employeeIds, _whereInLimit)) {
      final snapshot = await _guard(
        () => _firestore.leadsRef
            .where('assignedEmployeeId', whereIn: chunk)
            .get(),
      );
      for (final lead in mapDocs(snapshot, leadFromDoc)) {
        final id = lead.assignedEmployeeId;
        if (id == null) continue;
        (grouped[id] ??= <LeadModel>[]).add(lead);
      }
    }
    return grouped;
  }

  Future<Map<String, List<CallLogModel>>> _callsByEmployee(
    List<String> employeeIds,
    DateTime? start,
  ) async {
    final grouped = <String, List<CallLogModel>>{};
    for (final chunk in _chunk(employeeIds, _whereInLimit)) {
      var query =
          _firestore.callLogsRef.where('employeeId', whereIn: chunk);
      if (start != null) {
        query = query.where(
          'date',
          isGreaterThanOrEqualTo: writeTimestamp(start),
        );
      }
      final snapshot = await _guard(() => query.get());
      for (final call in mapDocs(snapshot, callLogFromDoc)) {
        (grouped[call.employeeId] ??= <CallLogModel>[]).add(call);
      }
    }
    return grouped;
  }

  Future<Map<String, List<FollowUpModel>>> _completedFollowUpsByEmployee(
    List<String> employeeIds,
    DateTime? start,
  ) async {
    final grouped = <String, List<FollowUpModel>>{};
    for (final chunk in _chunk(employeeIds, _whereInLimit)) {
      var query = _firestore.followUpsRef
          .where('employeeId', whereIn: chunk)
          .where('status', isEqualTo: FollowUpStatus.completed.name);
      if (start != null) {
        query = query.where(
          'completedAt',
          isGreaterThanOrEqualTo: writeTimestamp(start),
        );
      }
      final snapshot = await _guard(() => query.get());
      for (final followUp in mapDocs(snapshot, followUpFromDoc)) {
        (grouped[followUp.employeeId] ??= <FollowUpModel>[]).add(followUp);
      }
    }
    return grouped;
  }

  static Iterable<List<T>> _chunk<T>(List<T> source, int size) sync* {
    for (var i = 0; i < source.length; i += size) {
      yield source.sublist(
        i,
        i + size > source.length ? source.length : i + size,
      );
    }
  }

  static String _message(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'You do not have permission to view the leaderboard.',
      'failed-precondition' =>
        'The leaderboard needs a Firestore index that has not been created '
            'yet. Open the link in the console error to create it.',
      'unavailable' || 'network-request-failed' =>
        'No internet connection. Check your network and try again.',
      _ => error.message ?? 'Something went wrong. Please try again.',
    };
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FirebaseException catch (error) {
      throw LeaderboardRepositoryException(_message(error));
    }
  }
}
