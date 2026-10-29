import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/leaderboard_entry.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/shared_providers.dart';

class AdminDashboardData {
  const AdminDashboardData({
    required this.totalEmployees,
    required this.totalManagers,
    required this.activeToday,
    required this.totalLeads,
    required this.liveLeads,
    required this.claimedLeads,
    required this.wonLeads,
    required this.lostLeads,
    required this.callsToday,
    required this.followUpsToday,
    required this.overdueFollowUps,
    required this.leadsByStatus,
    required this.callsByDay,
    required this.conversionsByDay,
    required this.topPerformers,
  });

  final int totalEmployees;
  final int totalManagers;
  final int activeToday;
  final int totalLeads;
  final int liveLeads;
  final int claimedLeads;
  final int wonLeads;
  final int lostLeads;
  final int callsToday;
  final int followUpsToday;
  final int overdueFollowUps;
  final Map<LeadStatus, int> leadsByStatus;
  final List<(DateTime, int)> callsByDay;
  final List<(DateTime, int)> conversionsByDay;
  final List<LeaderboardEntry> topPerformers;

  LeaderboardEntry? get topPerformer =>
      topPerformers.isEmpty ? null : topPerformers.first;

  double get conversionRate {
    final closed = wonLeads + lostLeads;
    return closed == 0 ? 0 : (wonLeads / closed) * 100;
  }
}

final adminDashboardProvider =
    FutureProvider.autoDispose<AdminDashboardData>((ref) async {
  ref.watch(dataRevisionProvider);

  final users = await ref.read(userRepositoryProvider).getAllUsers();
  final leads = await ref.read(leadRepositoryProvider).getAllLeads();
  final calls = await ref.read(callLogRepositoryProvider).getAll();
  final followUps = await ref.read(followUpRepositoryProvider).getAll();
  final attendanceToday =
      await ref.read(attendanceRepositoryProvider).getForDate(DateTime.now());
  final board = await ref
      .read(leaderboardRepositoryProvider)
      .getLeaderboard(period: LeaderboardPeriod.thisMonth);

  final now = DateTime.now();

  return AdminDashboardData(
    totalEmployees:
        users.countWhere((u) => u.role == UserRole.employee && u.isActive),
    totalManagers:
        users.countWhere((u) => u.role == UserRole.manager && u.isActive),
    activeToday: attendanceToday.map((a) => a.employeeId).toSet().length,
    totalLeads: leads.length,
    liveLeads: leads.countWhere((l) => l.status == LeadStatus.live),
    claimedLeads: leads.countWhere((l) => l.assignedEmployeeId != null),
    wonLeads: leads.countWhere((l) => l.status == LeadStatus.won),
    lostLeads: leads.countWhere((l) => l.status == LeadStatus.lost),
    callsToday: calls.countWhere((c) => AppDate.isToday(c.date)),
    followUpsToday: followUps.countWhere(
      (f) => f.isOpen && AppDate.isSameDay(f.scheduledAt, now),
    ),
    overdueFollowUps: followUps
        .countWhere((f) => f.isOpen && f.scheduledAt.isBefore(now)),
    leadsByStatus: {
      for (final status in LeadStatus.values)
        status: leads.countWhere((l) => l.status == status),
    },
    callsByDay: [
      for (final day in AppDate.lastDays(7))
        (day, calls.countWhere((c) => AppDate.isSameDay(c.date, day))),
    ],
    conversionsByDay: [
      for (final day in AppDate.lastDays(30))
        (
          day,
          leads.countWhere(
            (l) =>
                l.status == LeadStatus.won &&
                AppDate.isSameDay(l.updatedAt, day),
          ),
        ),
    ],
    topPerformers: board.take(5).toList(growable: false),
  );
});
