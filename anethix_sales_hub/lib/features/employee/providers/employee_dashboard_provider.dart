import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/lead_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/shared_providers.dart';
import '../../auth/providers/auth_provider.dart';
import 'employee_follow_up_provider.dart';

class EmployeeDashboardData {
  const EmployeeDashboardData({
    required this.myLeadCount,
    required this.callsToday,
    required this.followUpsDue,
    required this.overdueCount,
    required this.score,
    required this.rank,
    required this.totalRanked,
    required this.todaysFollowUps,
    required this.recentActivity,
    required this.attendance,
  });

  final int myLeadCount;
  final int callsToday;
  final int followUpsDue;
  final int overdueCount;
  final int score;
  final int rank;
  final int totalRanked;
  final List<FollowUpWithLead> todaysFollowUps;
  final List<ActivityModel> recentActivity;
  final AttendanceModel? attendance;
}

final employeeDashboardProvider =
    FutureProvider.autoDispose<EmployeeDashboardData>((ref) async {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(authProvider);
  if (user == null) {
    throw StateError('The dashboard requires a signed-in user.');
  }

  final leadRepo = ref.read(leadRepositoryProvider);
  final leads = await leadRepo.getLeadsByEmployee(user.id);
  final leadsById = <String, LeadModel>{for (final l in leads) l.id: l};

  final calls = await ref.read(callLogRepositoryProvider).getByEmployee(user.id);
  final callsToday = calls.where((c) => AppDate.isToday(c.date)).length;

  final followUps =
      await ref.read(followUpRepositoryProvider).getByEmployee(user.id);
  final board = buildFollowUpBoard(followUps, leadsById);

  final entry = await ref
      .read(leaderboardRepositoryProvider)
      .getEntryFor(user.id, period: LeaderboardPeriod.thisMonth);
  final board2 = await ref
      .read(leaderboardRepositoryProvider)
      .getLeaderboard(period: LeaderboardPeriod.thisMonth);

  final activity =
      await ref.read(activityRepositoryProvider).getForUser(user.id, limit: 5);

  final attendance =
      await ref.read(attendanceRepositoryProvider).getToday(user.id);

  return EmployeeDashboardData(
    myLeadCount: leads.where((l) => l.status != LeadStatus.lost).length,
    callsToday: callsToday,
    followUpsDue: board.today.length,
    overdueCount: board.overdue.length,
    score: entry?.score ?? 0,
    rank: entry?.rank ?? 0,
    totalRanked: board2.length,
    todaysFollowUps: board.today,
    recentActivity: activity,
    attendance: attendance,
  );
});
