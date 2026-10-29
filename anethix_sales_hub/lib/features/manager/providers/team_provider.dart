import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/models/lead_model.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/shared_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../employee/providers/employee_follow_up_provider.dart';

/// Roll-up shown on a team member card.
class TeamMemberSummary {
  const TeamMemberSummary({
    required this.user,
    required this.leadsTaken,
    required this.callsMade,
    required this.activeFollowUps,
    required this.score,
    required this.isCheckedInToday,
  });

  final UserModel user;
  final int leadsTaken;
  final int callsMade;
  final int activeFollowUps;
  final int score;
  final bool isCheckedInToday;
}

final teamProvider =
    FutureProvider.autoDispose<List<TeamMemberSummary>>((ref) async {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(authProvider);
  if (user == null) return const [];

  final members = await ref.read(userRepositoryProvider).getTeamMembers(user.id);
  final board = await ref
      .read(leaderboardRepositoryProvider)
      .getLeaderboard(period: LeaderboardPeriod.allTime, managerId: user.id);
  final scores = {for (final e in board) e.employeeId: e.score};
  final today =
      await ref.read(attendanceRepositoryProvider).getForDate(DateTime.now());
  final checkedIn = today.map((a) => a.employeeId).toSet();

  final leadRepo = ref.read(leadRepositoryProvider);
  final callRepo = ref.read(callLogRepositoryProvider);
  final followUpRepo = ref.read(followUpRepositoryProvider);

  final summaries = <TeamMemberSummary>[];
  for (final member in members) {
    final leads = await leadRepo.getLeadsByEmployee(member.id);
    final calls = await callRepo.getByEmployee(member.id);
    final followUps = await followUpRepo.getByEmployee(member.id);

    summaries.add(
      TeamMemberSummary(
        user: member,
        leadsTaken: leads.length,
        callsMade: calls.length,
        activeFollowUps: followUps.countWhere((f) => f.isOpen),
        score: scores[member.id] ?? 0,
        isCheckedInToday: checkedIn.contains(member.id),
      ),
    );
  }

  summaries.sort((a, b) => b.score.compareTo(a.score));
  return summaries;
});

/// Full performance picture for one employee, used by the manager drill-down
/// and (with a different header) by the admin user detail screen.
class EmployeePerformance {
  const EmployeePerformance({
    required this.user,
    required this.leads,
    required this.totalCalls,
    required this.connectedCalls,
    required this.followUpsTotal,
    required this.followUpsCompleted,
    required this.overdueFollowUps,
    required this.meetings,
    required this.won,
    required this.lost,
    required this.score,
    required this.rank,
    required this.callsByDay,
    required this.recentActivity,
    required this.stuckLeads,
    required this.attendanceDays,
  });

  final UserModel user;
  final List<LeadModel> leads;
  final int totalCalls;
  final int connectedCalls;
  final int followUpsTotal;
  final int followUpsCompleted;
  final int overdueFollowUps;
  final int meetings;
  final int won;
  final int lost;
  final int score;
  final int rank;
  final List<(DateTime, int)> callsByDay;
  final List<ActivityModel> recentActivity;

  /// Claimed leads with no activity for [AppConstants.stuckLeadDays] days.
  final List<LeadModel> stuckLeads;
  final int attendanceDays;
}

final employeePerformanceProvider = FutureProvider.autoDispose
    .family<EmployeePerformance, String>((ref, employeeId) async {
  ref.watch(dataRevisionProvider);

  final user = await ref.read(userRepositoryProvider).getUserById(employeeId);
  final leads =
      await ref.read(leadRepositoryProvider).getLeadsByEmployee(employeeId);
  final calls =
      await ref.read(callLogRepositoryProvider).getByEmployee(employeeId);
  final followUps =
      await ref.read(followUpRepositoryProvider).getByEmployee(employeeId);
  final activity = await ref
      .read(activityRepositoryProvider)
      .getForUser(employeeId, limit: 10);
  final attendance =
      await ref.read(attendanceRepositoryProvider).getHistory(employeeId);

  final board = await ref
      .read(leaderboardRepositoryProvider)
      .getLeaderboard(period: LeaderboardPeriod.allTime);
  final entry = board.firstWhereOrNull((e) => e.employeeId == employeeId);

  final now = DateTime.now();
  final stuckCutoff =
      now.subtract(const Duration(days: AppConstants.stuckLeadDays));

  return EmployeePerformance(
    user: user,
    leads: leads,
    totalCalls: calls.length,
    connectedCalls: calls.countWhere((c) => c.outcome.isConnected),
    followUpsTotal: followUps.length,
    followUpsCompleted:
        followUps.countWhere((f) => f.status == FollowUpStatus.completed),
    overdueFollowUps: followUps
        .countWhere((f) => f.isOpen && f.scheduledAt.isBefore(now)),
    meetings: leads.countWhere((l) => l.status == LeadStatus.meeting),
    won: leads.countWhere((l) => l.status == LeadStatus.won),
    lost: leads.countWhere((l) => l.status == LeadStatus.lost),
    score: entry?.score ?? 0,
    rank: entry?.rank ?? 0,
    callsByDay: [
      for (final day in AppDate.lastDays(7))
        (day, calls.countWhere((c) => AppDate.isSameDay(c.date, day))),
    ],
    recentActivity: activity,
    stuckLeads: leads
        .where((l) =>
            l.assignedEmployeeId == employeeId &&
            l.status != LeadStatus.won &&
            l.status != LeadStatus.lost &&
            (l.lastActivityAt ?? l.updatedAt).isBefore(stuckCutoff))
        .toList(growable: false),
    attendanceDays: attendance.length,
  );
});

/// Team-wide follow-up board for the manager overview screen.
final managerFollowUpBoardProvider =
    FutureProvider.autoDispose<FollowUpBoard>((ref) async {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(authProvider);
  if (user == null) return FollowUpBoard.empty;

  final members = await ref.read(userRepositoryProvider).getTeamMembers(user.id);
  final ids = members.map((m) => m.id).toList(growable: false);
  final followUps =
      await ref.read(followUpRepositoryProvider).getByEmployees(ids);

  final leadRepo = ref.read(leadRepositoryProvider);
  final leadsById = <String, LeadModel>{};
  for (final id in ids) {
    for (final lead in await leadRepo.getLeadsByEmployee(id)) {
      leadsById[lead.id] = lead;
    }
  }

  return buildFollowUpBoard(followUps, leadsById);
});
