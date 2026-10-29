import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/leaderboard_entry.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/shared_providers.dart';
import '../../auth/providers/auth_provider.dart';

final leaderboardPeriodProvider =
    StateProvider<LeaderboardPeriod>((ref) => LeaderboardPeriod.thisMonth);

final leaderboardProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  ref.watch(dataRevisionProvider);
  final period = ref.watch(leaderboardPeriodProvider);
  return ref.read(leaderboardRepositoryProvider).getLeaderboard(period: period);
});

/// The signed-in employee's own row, or null for admins and managers.
final myLeaderboardEntryProvider =
    Provider.autoDispose<AsyncValue<LeaderboardEntry?>>((ref) {
  final user = ref.watch(authProvider);
  return ref.watch(leaderboardProvider).whenData((entries) {
    if (user == null || user.role != UserRole.employee) return null;
    for (final entry in entries) {
      if (entry.employeeId == user.id) return entry;
    }
    return null;
  });
});

/// Leaderboard scoped to one manager's team.
final teamLeaderboardProvider = FutureProvider.autoDispose
    .family<List<LeaderboardEntry>, String>((ref, managerId) async {
  ref.watch(dataRevisionProvider);
  final period = ref.watch(leaderboardPeriodProvider);
  return ref
      .read(leaderboardRepositoryProvider)
      .getLeaderboard(period: period, managerId: managerId);
});
