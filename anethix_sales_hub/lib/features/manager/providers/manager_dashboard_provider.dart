import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/lead_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/shared_providers.dart';
import '../../auth/providers/auth_provider.dart';

class ManagerDashboardData {
  const ManagerDashboardData({
    required this.totalLeads,
    required this.newLeads,
    required this.liveLeads,
    required this.availableLeads,
    required this.claimedLeads,
    required this.contactedLeads,
    required this.followUpsDue,
    required this.followUpsOverdue,
    required this.followUpsCompleted,
    required this.wonLeads,
    required this.lostLeads,
    required this.teamSize,
    required this.callsToday,
    required this.claimedToday,
    required this.meetings,
    required this.teamScore,
    required this.leadsByStatus,
    required this.callsByDay,
  });

  final int totalLeads;
  final int newLeads;
  final int liveLeads;
  final int availableLeads;
  final int claimedLeads;
  final int contactedLeads;
  final int followUpsDue;
  final int followUpsOverdue;
  final int followUpsCompleted;
  final int wonLeads;
  final int lostLeads;
  final int teamSize;
  final int callsToday;
  final int claimedToday;
  final int meetings;
  final int teamScore;
  final Map<LeadStatus, int> leadsByStatus;

  /// (day, call count) for the last 7 days, oldest first.
  final List<(DateTime, int)> callsByDay;

  /// Won as a share of everything that reached a decision.
  double get conversionRate {
    final closed = wonLeads + lostLeads;
    return closed == 0 ? 0 : (wonLeads / closed) * 100;
  }
}

final managerDashboardProvider =
    FutureProvider.autoDispose<ManagerDashboardData>((ref) async {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(authProvider);
  if (user == null) {
    throw StateError('The manager dashboard requires a signed-in user.');
  }

  final leads = await ref.read(leadRepositoryProvider).getLeadsByManager(user.id);
  final team = await ref.read(userRepositoryProvider).getTeamMembers(user.id);
  final teamIds = team.map((u) => u.id).toList(growable: false);

  final followUps =
      await ref.read(followUpRepositoryProvider).getByEmployees(teamIds);
  final allCalls = await ref.read(callLogRepositoryProvider).getAll();
  final teamIdSet = teamIds.toSet();
  final teamCalls =
      allCalls.where((c) => teamIdSet.contains(c.employeeId)).toList();

  final board = await ref
      .read(leaderboardRepositoryProvider)
      .getLeaderboard(period: LeaderboardPeriod.thisMonth, managerId: user.id);

  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));

  final byStatus = <LeadStatus, int>{
    for (final status in LeadStatus.values)
      status: leads.countWhere((l) => l.status == status),
  };

  final callsByDay = [
    for (final day in AppDate.lastDays(7))
      (day, teamCalls.countWhere((c) => AppDate.isSameDay(c.date, day))),
  ];

  return ManagerDashboardData(
    totalLeads: leads.length,
    newLeads: leads.countWhere((l) => l.createdAt.isAfter(weekAgo)),
    liveLeads: leads.countWhere((l) => l.status == LeadStatus.live),
    availableLeads: leads.countWhere((l) => l.isAvailable),
    claimedLeads: leads.countWhere((l) => l.assignedEmployeeId != null),
    contactedLeads: leads.countWhere(
      (l) => l.status == LeadStatus.contacted || l.status == LeadStatus.interested,
    ),
    followUpsDue: followUps.countWhere(
      (f) => f.isOpen && AppDate.isSameDay(f.scheduledAt, now),
    ),
    followUpsOverdue: followUps.countWhere(
      (f) => f.isOpen && f.scheduledAt.isBefore(now),
    ),
    followUpsCompleted:
        followUps.countWhere((f) => f.status == FollowUpStatus.completed),
    wonLeads: byStatus[LeadStatus.won] ?? 0,
    lostLeads: byStatus[LeadStatus.lost] ?? 0,
    teamSize: team.length,
    callsToday: teamCalls.countWhere((c) => AppDate.isToday(c.date)),
    claimedToday: leads.countWhere(
      (l) => l.claimedAt != null && AppDate.isToday(l.claimedAt!),
    ),
    meetings: leads.countWhere((l) => l.status == LeadStatus.meeting),
    teamScore: board.fold<int>(0, (sum, entry) => sum + entry.score),
    leadsByStatus: byStatus,
    callsByDay: callsByDay,
  );
});

/// Follow-ups across the whole team, bucketed for the manager's overview.
final managerTeamLeadsProvider =
    FutureProvider.autoDispose<List<LeadModel>>((ref) async {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(authProvider);
  if (user == null) return const [];

  final team = await ref.read(userRepositoryProvider).getTeamMembers(user.id);
  final leadRepo = ref.read(leadRepositoryProvider);
  final result = <LeadModel>[];
  for (final member in team) {
    result.addAll(await leadRepo.getLeadsByEmployee(member.id));
  }
  return result;
});
