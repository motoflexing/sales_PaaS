import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../data/models/follow_up_model.dart';
import '../../../data/models/lead_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/shared_providers.dart';
import '../../auth/providers/auth_provider.dart';

enum FollowUpTab { today, upcoming, overdue, completed }

extension FollowUpTabX on FollowUpTab {
  String get label => switch (this) {
        FollowUpTab.today => 'Today',
        FollowUpTab.upcoming => 'Upcoming',
        FollowUpTab.overdue => 'Overdue',
        FollowUpTab.completed => 'Completed',
      };
}

/// A follow-up paired with the lead it belongs to, so cards can show context
/// without a second lookup per row.
class FollowUpWithLead {
  const FollowUpWithLead({required this.followUp, required this.lead});

  final FollowUpModel followUp;
  final LeadModel? lead;

  bool get isOverdue =>
      followUp.status == FollowUpStatus.overdue ||
      (followUp.isOpen && followUp.scheduledAt.isBefore(DateTime.now()));
}

class FollowUpBoard {
  const FollowUpBoard({
    required this.today,
    required this.upcoming,
    required this.overdue,
    required this.completed,
  });

  final List<FollowUpWithLead> today;
  final List<FollowUpWithLead> upcoming;
  final List<FollowUpWithLead> overdue;
  final List<FollowUpWithLead> completed;

  static const FollowUpBoard empty = FollowUpBoard(
    today: [],
    upcoming: [],
    overdue: [],
    completed: [],
  );

  List<FollowUpWithLead> forTab(FollowUpTab tab) => switch (tab) {
        FollowUpTab.today => today,
        FollowUpTab.upcoming => upcoming,
        FollowUpTab.overdue => overdue,
        FollowUpTab.completed => completed,
      };

  int get openCount => today.length + upcoming.length + overdue.length;
}

/// Buckets follow-ups into the four tabs. Overdue is sorted most-overdue first.
FollowUpBoard buildFollowUpBoard(
  List<FollowUpModel> followUps,
  Map<String, LeadModel> leadsById,
) {
  final now = DateTime.now();
  final today = <FollowUpWithLead>[];
  final upcoming = <FollowUpWithLead>[];
  final overdue = <FollowUpWithLead>[];
  final completed = <FollowUpWithLead>[];

  for (final followUp in followUps) {
    final entry = FollowUpWithLead(
      followUp: followUp,
      lead: leadsById[followUp.leadId],
    );

    if (followUp.status == FollowUpStatus.completed) {
      completed.add(entry);
    } else if (AppDate.isSameDay(followUp.scheduledAt, now)) {
      today.add(entry);
    } else if (followUp.scheduledAt.isBefore(now)) {
      overdue.add(entry);
    } else {
      upcoming.add(entry);
    }
  }

  today.sort((a, b) => a.followUp.scheduledAt.compareTo(b.followUp.scheduledAt));
  upcoming
      .sort((a, b) => a.followUp.scheduledAt.compareTo(b.followUp.scheduledAt));
  overdue
      .sort((a, b) => a.followUp.scheduledAt.compareTo(b.followUp.scheduledAt));
  completed.sort(
    (a, b) => (b.followUp.completedAt ?? b.followUp.scheduledAt)
        .compareTo(a.followUp.completedAt ?? a.followUp.scheduledAt),
  );

  return FollowUpBoard(
    today: today,
    upcoming: upcoming,
    overdue: overdue,
    completed: completed,
  );
}

/// Buckets an employee's follow-ups into the four tabs.
///
/// Two Firestore subscriptions feed this: the employee's follow-ups and the
/// leads they own (each card shows the lead's name alongside the follow-up).
/// The board is rebuilt whenever either side emits, so completing a follow-up
/// on one device updates the tabs on another.
class EmployeeFollowUpNotifier extends AsyncNotifier<FollowUpBoard> {
  StreamSubscription<List<FollowUpModel>>? _followUpSubscription;
  StreamSubscription<List<LeadModel>>? _leadSubscription;

  List<FollowUpModel>? _followUps;
  List<LeadModel>? _leads;
  Completer<FollowUpBoard>? _first;

  @override
  Future<FollowUpBoard> build() {
    final user = ref.watch(authProvider);
    if (user == null) return Future.value(FollowUpBoard.empty);

    _followUps = null;
    _leads = null;
    final first = Completer<FollowUpBoard>();
    _first = first;

    _followUpSubscription?.cancel();
    _followUpSubscription = ref
        .read(followUpRepositoryProvider)
        .watchByEmployee(user.id)
        .listen(
          (followUps) {
            _followUps = followUps;
            _emit();
          },
          onError: _fail,
        );

    _leadSubscription?.cancel();
    _leadSubscription = ref
        .read(leadRepositoryProvider)
        .watchLeadsByEmployee(user.id)
        .listen(
          (leads) {
            _leads = leads;
            _emit();
          },
          onError: _fail,
        );

    ref.onDispose(() {
      _followUpSubscription?.cancel();
      _leadSubscription?.cancel();
    });

    return first.future;
  }

  /// Publishes a board once both streams have delivered their first snapshot,
  /// so the tabs never render follow-ups with their lead context missing.
  void _emit() {
    final followUps = _followUps;
    final leads = _leads;
    if (followUps == null || leads == null) return;

    final board = buildFollowUpBoard(
      followUps,
      {for (final lead in leads) lead.id: lead},
    );

    final first = _first;
    if (first != null && !first.isCompleted) {
      first.complete(board);
    } else {
      state = AsyncData(board);
    }
  }

  void _fail(Object error, StackTrace stackTrace) {
    final first = _first;
    if (first != null && !first.isCompleted) {
      first.completeError(error, stackTrace);
    } else {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    final user = ref.read(authProvider);
    if (user == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final followUps =
          await ref.read(followUpRepositoryProvider).getByEmployee(user.id);
      final leads =
          await ref.read(leadRepositoryProvider).getLeadsByEmployee(user.id);
      return buildFollowUpBoard(
        followUps,
        {for (final lead in leads) lead.id: lead},
      );
    });
  }

  Future<void> complete(String followUpId, {String? remark}) async {
    await ref
        .read(followUpRepositoryProvider)
        .complete(followUpId, remark: remark);
    ref.bumpDataRevision();
  }

  Future<void> reschedule(String followUpId, DateTime scheduledAt) async {
    await ref
        .read(followUpRepositoryProvider)
        .reschedule(followUpId, scheduledAt);
    ref.bumpDataRevision();
  }
}

final employeeFollowUpProvider =
    AsyncNotifierProvider<EmployeeFollowUpNotifier, FollowUpBoard>(
  EmployeeFollowUpNotifier.new,
);
