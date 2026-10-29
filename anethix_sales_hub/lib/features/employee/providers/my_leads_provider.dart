import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/extensions.dart';
import '../../../data/models/lead_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/shared_providers.dart';
import '../../auth/providers/auth_provider.dart';

/// Leads currently assigned to the signed-in employee.
///
/// Backed by a Firestore `snapshots()` subscription, so a status change made on
/// another device — or a lead reassigned by a manager — lands here without a
/// refresh. Emissions are pushed into [AsyncData] directly to avoid flashing
/// the loading state on every update.
class MyLeadsNotifier extends AsyncNotifier<List<LeadModel>> {
  StreamSubscription<List<LeadModel>>? _subscription;

  @override
  Future<List<LeadModel>> build() {
    final user = ref.watch(authProvider);
    if (user == null) return Future.value(const []);

    final first = Completer<List<LeadModel>>();

    _subscription?.cancel();
    _subscription = ref
        .read(leadRepositoryProvider)
        .watchLeadsByEmployee(user.id)
        .listen(
          (leads) {
            if (first.isCompleted) {
              state = AsyncData(leads);
            } else {
              first.complete(leads);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (first.isCompleted) {
              state = AsyncError(error, stackTrace);
            } else {
              first.completeError(error, stackTrace);
            }
          },
        );
    ref.onDispose(() => _subscription?.cancel());

    return first.future;
  }

  Future<void> refresh() async {
    final user = ref.read(authProvider);
    if (user == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(leadRepositoryProvider).getLeadsByEmployee(user.id),
    );
  }

  Future<void> updateStatus(String leadId, LeadStatus status) async {
    final user = ref.read(authProvider);
    if (user == null) return;
    await ref
        .read(leadRepositoryProvider)
        .updateStatus(leadId, status, user.id);
    ref.bumpDataRevision();
  }
}

final myLeadsProvider = AsyncNotifierProvider<MyLeadsNotifier, List<LeadModel>>(
  MyLeadsNotifier.new,
);

/// Buckets offered as filter chips on My Leads. Declaration order is the chip
/// order on screen.
///
/// All but [MyLeadsFilter.assigned] are status buckets; `assigned` is about
/// provenance instead — how the lead reached this rep — so it cuts across every
/// status.
enum MyLeadsFilter {
  all,
  assigned,
  claimed,
  contacted,
  followUp,
  meeting,
  won,
  lost,
}

extension MyLeadsFilterX on MyLeadsFilter {
  String get label => switch (this) {
    MyLeadsFilter.all => 'All',
    MyLeadsFilter.assigned => 'Assigned',
    MyLeadsFilter.claimed => 'Claimed',
    MyLeadsFilter.contacted => 'Contacted',
    MyLeadsFilter.followUp => 'Follow-up',
    MyLeadsFilter.meeting => 'Meeting',
    MyLeadsFilter.won => 'Won',
    MyLeadsFilter.lost => 'Lost',
  };

  /// Status-only test, kept for the buckets that are purely status-based.
  /// [MyLeadsFilter.assigned] is not one of them — it always says true here and
  /// is decided by [matchesLead].
  bool matches(LeadStatus status) => switch (this) {
    MyLeadsFilter.all => true,
    MyLeadsFilter.assigned => true,
    MyLeadsFilter.claimed => status == LeadStatus.claimed,
    MyLeadsFilter.contacted =>
      status == LeadStatus.contacted || status == LeadStatus.interested,
    MyLeadsFilter.followUp => status == LeadStatus.followUp,
    MyLeadsFilter.meeting =>
      status == LeadStatus.meeting || status == LeadStatus.proposal,
    MyLeadsFilter.won => status == LeadStatus.won,
    MyLeadsFilter.lost => status == LeadStatus.lost,
  };

  /// Whole-lead test used by the filtered list.
  ///
  /// A lead counts as directly assigned when a manager handed it over rather
  /// than the rep claiming it off the live board: it is theirs, and somebody
  /// else published it.
  bool matchesLead(LeadModel lead, String? currentUserId) => switch (this) {
    MyLeadsFilter.assigned =>
      currentUserId != null &&
          lead.assignedEmployeeId == currentUserId &&
          lead.publishedBy != null &&
          lead.publishedBy != currentUserId,
    _ => matches(lead.status),
  };
}

final myLeadsFilterProvider = StateProvider.autoDispose<MyLeadsFilter>(
  (ref) => MyLeadsFilter.all,
);

final myLeadsQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final filteredMyLeadsProvider =
    Provider.autoDispose<AsyncValue<List<LeadModel>>>((ref) {
      final filter = ref.watch(myLeadsFilterProvider);
      final query = ref.watch(myLeadsQueryProvider);
      final currentUserId = ref.watch(authProvider)?.id;

      return ref.watch(myLeadsProvider).whenData((leads) {
        return leads
            .where((lead) {
              if (!filter.matchesLead(lead, currentUserId)) return false;
              if (query.isEmpty) return true;
              return lead.name.containsIgnoreCase(query) ||
                  (lead.company?.containsIgnoreCase(query) ?? false) ||
                  lead.phone.contains(query);
            })
            .toList(growable: false);
      });
    });

// ----------------------------- Remark badges -----------------------------
//
// The My Leads card shows, per lead, whether remarks exist and how many the
// reader has not seen. Both halves are kept out of the card itself: the counts
// come from one batched query, and "seen" is local, per-device bookkeeping.

/// Every remark timestamp for the signed-in employee's leads, keyed by lead id.
///
/// Cached by Riverpod and re-fetched only when the leads list or the data
/// revision changes, so scrolling the list costs nothing.
final leadRemarkTimesProvider =
    FutureProvider.autoDispose<Map<String, List<DateTime>>>((ref) async {
      ref.watch(dataRevisionProvider);
      final leads = await ref.watch(myLeadsProvider.future);
      if (leads.isEmpty) return const {};

      return ref.read(leadRepositoryProvider).getRemarkTimesByLeads([
        for (final lead in leads) lead.id,
      ]);
    });

/// Lead id to total remark count.
final leadRemarkCountsProvider = FutureProvider.autoDispose<Map<String, int>>((
  ref,
) async {
  final times = await ref.watch(leadRemarkTimesProvider.future);
  return {for (final entry in times.entries) entry.key: entry.value.length};
});

/// When this user last looked at a lead's remarks, per lead.
///
/// Device-local on purpose: "have I read this?" is not shared state, and
/// SharedPreferences keeps it out of Firestore (and out of the security rules).
class RemarkViewsNotifier extends Notifier<Map<String, DateTime>> {
  static const String _prefix = 'remarks_last_viewed_';

  @override
  Map<String, DateTime> build() {
    final userId = ref.watch(authProvider)?.id;
    if (userId == null) return const {};
    // Prefs are async; the map fills in a moment later and the badges rebuild.
    unawaited(_load(userId));
    return const {};
  }

  static String _key(String leadId, String userId) =>
      '$_prefix${leadId}_$userId';

  Future<void> _load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final suffix = '_$userId';
      final loaded = <String, DateTime>{};
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_prefix) || !key.endsWith(suffix)) continue;
        final stamp = prefs.getInt(key);
        if (stamp == null) continue;
        // Slice the id out rather than splitting, so an id containing an
        // underscore still resolves.
        final leadId = key.substring(
          _prefix.length,
          key.length - suffix.length,
        );
        if (leadId.isEmpty) continue;
        loaded[leadId] = DateTime.fromMillisecondsSinceEpoch(stamp);
      }
      state = loaded;
    } on Object {
      // Unreadable prefs just mean everything reads as unseen.
    }
  }

  /// Records that the reader has just seen this lead's remarks.
  Future<void> markViewed(String leadId) async {
    final userId = ref.read(authProvider)?.id;
    if (userId == null) return;

    final now = DateTime.now();
    state = {...state, leadId: now};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(leadId, userId), now.millisecondsSinceEpoch);
    } on Object {
      // The in-memory state already cleared the badge for this session.
    }
  }
}

final remarkViewsProvider =
    NotifierProvider<RemarkViewsNotifier, Map<String, DateTime>>(
      RemarkViewsNotifier.new,
    );

/// What the card draws: how many remarks a lead has, and how many are new.
class RemarkBadge {
  const RemarkBadge({required this.total, required this.unread});

  final int total;
  final int unread;

  bool get hasAny => total > 0;
}

/// Counts a lead's remarks as unread when they were written after the reader
/// last opened that lead. Never having opened it makes every remark unread.
RemarkBadge remarkBadgeFor(List<DateTime> times, DateTime? lastViewed) {
  if (times.isEmpty) return const RemarkBadge(total: 0, unread: 0);
  final unread = lastViewed == null
      ? times.length
      : times.where((at) => at.isAfter(lastViewed)).length;
  return RemarkBadge(total: times.length, unread: unread);
}

/// Badge state for every lead in the My Leads list.
final leadRemarkBadgesProvider = Provider.autoDispose<Map<String, RemarkBadge>>(
  (ref) {
    final times = ref.watch(leadRemarkTimesProvider).valueOrNull ?? const {};
    final views = ref.watch(remarkViewsProvider);

    return {
      for (final entry in times.entries)
        entry.key: remarkBadgeFor(entry.value, views[entry.key]),
    };
  },
);
