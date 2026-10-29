import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/attendance_model.dart';
import '../../../shared/providers/shared_providers.dart';
import '../../auth/providers/auth_provider.dart';

class AttendanceState {
  const AttendanceState({required this.today, required this.history});

  final AttendanceModel? today;
  final List<AttendanceModel> history;

  bool get isCheckedIn => today != null && today!.checkOut == null;
  bool get isCheckedOut => today != null && today!.checkOut != null;

  /// Days marked present in the loaded history window.
  int get presentDays => history.length;

  double get totalHours => history.fold<double>(
        0,
        (sum, record) => sum + (record.workingHours ?? 0),
      );

  double get averageHours =>
      history.isEmpty ? 0 : totalHours / history.length;
}

class AttendanceNotifier extends AsyncNotifier<AttendanceState> {
  @override
  Future<AttendanceState> build() async {
    ref.watch(dataRevisionProvider);
    final user = ref.watch(authProvider);
    if (user == null) {
      return const AttendanceState(today: null, history: []);
    }

    final repo = ref.read(attendanceRepositoryProvider);
    final today = await repo.getToday(user.id);
    final history = await repo.getHistory(user.id);
    return AttendanceState(today: today, history: history);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> checkIn() async {
    final user = ref.read(authProvider);
    if (user == null) return;
    await ref.read(attendanceRepositoryProvider).checkIn(user.id);
    ref.bumpDataRevision();
  }

  Future<void> checkOut() async {
    final user = ref.read(authProvider);
    if (user == null) return;
    await ref.read(attendanceRepositoryProvider).checkOut(user.id);
    ref.bumpDataRevision();
  }
}

final attendanceProvider =
    AsyncNotifierProvider<AttendanceNotifier, AttendanceState>(
  AttendanceNotifier.new,
);
