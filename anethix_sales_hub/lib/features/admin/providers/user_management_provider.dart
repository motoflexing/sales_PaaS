import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/lead_model.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/shared_providers.dart';
import '../../auth/providers/auth_provider.dart';

enum UserListTab { all, managers, employees, inactive }

extension UserListTabX on UserListTab {
  String get label => switch (this) {
        UserListTab.all => 'All',
        UserListTab.managers => 'Managers',
        UserListTab.employees => 'Employees',
        UserListTab.inactive => 'Inactive',
      };

  bool matches(UserModel user) => switch (this) {
        UserListTab.all => true,
        UserListTab.managers => user.role == UserRole.manager,
        UserListTab.employees => user.role == UserRole.employee,
        UserListTab.inactive => !user.isActive,
      };
}

class UserManagementNotifier extends AsyncNotifier<List<UserModel>> {
  @override
  Future<List<UserModel>> build() async {
    ref.watch(dataRevisionProvider);
    return ref.read(userRepositoryProvider).getAllUsers();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<UserModel> createUser({
    required String name,
    required String email,
    required String phone,
    required UserRole role,
    required String password,
    String? managerId,
  }) async {
    final admin = ref.read(authProvider);
    final user = await ref.read(userRepositoryProvider).createUser(
          name: name,
          email: email,
          phone: phone,
          role: role,
          password: password,
          managerId: managerId,
          createdByUserId: admin?.id ?? 'system',
        );
    ref.bumpDataRevision();
    return user;
  }

  Future<void> setActive(String userId, bool isActive) async {
    await ref.read(userRepositoryProvider).setActive(userId, isActive);
    ref.bumpDataRevision();
  }

  Future<void> assignManager(String employeeId, String? managerId) async {
    await ref.read(userRepositoryProvider).assignManager(employeeId, managerId);
    ref.bumpDataRevision();
  }

  Future<void> updateUser({
    required String userId,
    String? name,
    String? phone,
  }) async {
    await ref
        .read(userRepositoryProvider)
        .updateUser(userId: userId, name: name, phone: phone);
    ref.bumpDataRevision();
  }
}

final userManagementProvider =
    AsyncNotifierProvider<UserManagementNotifier, List<UserModel>>(
  UserManagementNotifier.new,
);

final userListTabProvider =
    StateProvider.autoDispose<UserListTab>((ref) => UserListTab.all);

final userListQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final filteredUsersProvider =
    Provider.autoDispose<AsyncValue<List<UserModel>>>((ref) {
  final tab = ref.watch(userListTabProvider);
  final query = ref.watch(userListQueryProvider);

  return ref.watch(userManagementProvider).whenData((users) {
    final visible = users.where((user) {
      // Admins manage staff, not themselves.
      if (user.role == UserRole.admin) return false;
      // Deactivated accounts live in their own tab.
      if (tab != UserListTab.inactive && !user.isActive) return false;
      if (!tab.matches(user)) return false;
      if (query.isEmpty) return true;
      return user.name.containsIgnoreCase(query) ||
          user.email.containsIgnoreCase(query);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return visible;
  });
});

final activeManagersProvider = FutureProvider<List<UserModel>>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.read(userRepositoryProvider).getActiveManagers();
});

/// Everything the admin user-detail screen shows for one person.
class UserDetail {
  const UserDetail({
    required this.user,
    required this.manager,
    required this.leads,
    required this.attendanceDays,
    required this.calls,
    required this.followUps,
    required this.meetings,
    required this.conversions,
    required this.score,
  });

  final UserModel user;
  final UserModel? manager;
  final List<LeadModel> leads;
  final int attendanceDays;
  final int calls;
  final int followUps;
  final int meetings;
  final int conversions;
  final int score;
}

final userDetailProvider =
    FutureProvider.autoDispose.family<UserDetail, String>((ref, userId) async {
  ref.watch(dataRevisionProvider);

  final userRepo = ref.read(userRepositoryProvider);
  final user = await userRepo.getUserById(userId);

  UserModel? manager;
  if (user.managerId != null) {
    try {
      manager = await userRepo.getUserById(user.managerId!);
    } on Exception {
      manager = null;
    }
  }

  if (user.role != UserRole.employee) {
    return UserDetail(
      user: user,
      manager: manager,
      leads: const [],
      attendanceDays: 0,
      calls: 0,
      followUps: 0,
      meetings: 0,
      conversions: 0,
      score: 0,
    );
  }

  final leads = await ref.read(leadRepositoryProvider).getLeadsByEmployee(userId);
  final calls = await ref.read(callLogRepositoryProvider).getByEmployee(userId);
  final followUps =
      await ref.read(followUpRepositoryProvider).getByEmployee(userId);
  final attendance =
      await ref.read(attendanceRepositoryProvider).getHistory(userId);
  final board = await ref
      .read(leaderboardRepositoryProvider)
      .getLeaderboard(period: LeaderboardPeriod.allTime);

  return UserDetail(
    user: user,
    manager: manager,
    leads: leads,
    attendanceDays: attendance.length,
    calls: calls.length,
    followUps:
        followUps.countWhere((f) => f.status == FollowUpStatus.completed),
    meetings: leads.countWhere((l) => l.status == LeadStatus.meeting),
    conversions: leads.countWhere((l) => l.status == LeadStatus.won),
    score: board.firstWhereOrNull((e) => e.employeeId == userId)?.score ?? 0,
  );
});

/// Attendance for a chosen date, joined to the staff directory.
class AttendanceDaySnapshot {
  const AttendanceDaySnapshot({
    required this.date,
    required this.staff,
    required this.records,
  });

  final DateTime date;
  final List<UserModel> staff;
  final Map<String, AttendanceModel> records;

  int get present => records.length;
  int get absent => staff.length - present;
  int get late => records.values.countWhere((r) => r.isLate);
}

final adminAttendanceDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final adminAttendanceProvider =
    FutureProvider.autoDispose<AttendanceDaySnapshot>((ref) async {
  ref.watch(dataRevisionProvider);
  final date = ref.watch(adminAttendanceDateProvider);

  final users = await ref.read(userRepositoryProvider).getAllUsers();
  final staff = users
      .where((u) => u.role != UserRole.admin && u.isActive)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  final records = await ref.read(attendanceRepositoryProvider).getForDate(date);

  return AttendanceDaySnapshot(
    date: date,
    staff: staff,
    records: {for (final r in records) r.employeeId: r},
  );
});

/// Every lead in the company, for the admin lead browser.
final adminLeadsProvider =
    FutureProvider.autoDispose<List<LeadModel>>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.read(leadRepositoryProvider).getAllLeads();
});

final adminLeadQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final adminLeadStatusFilterProvider =
    StateProvider.autoDispose<LeadStatus?>((ref) => null);

final filteredAdminLeadsProvider =
    Provider.autoDispose<AsyncValue<List<LeadModel>>>((ref) {
  final query = ref.watch(adminLeadQueryProvider);
  final status = ref.watch(adminLeadStatusFilterProvider);

  return ref.watch(adminLeadsProvider).whenData((leads) {
    return leads.where((lead) {
      if (status != null && lead.status != status) return false;
      if (query.isEmpty) return true;
      return lead.name.containsIgnoreCase(query) ||
          (lead.company?.containsIgnoreCase(query) ?? false) ||
          lead.phone.contains(query);
    }).toList(growable: false);
  });
});
