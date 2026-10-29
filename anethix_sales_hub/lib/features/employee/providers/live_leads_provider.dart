import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../data/models/lead_model.dart';
import '../../../shared/providers/shared_providers.dart';

/// The marketplace of unclaimed live leads.
///
/// Backed by a Firestore `snapshots()` subscription: when a manager publishes a
/// lead or another rep claims one, the board here changes without anyone
/// pulling to refresh. Emissions are pushed straight into [AsyncData] rather
/// than re-running `build`, so a live update never flashes the loading state.
class LiveLeadsNotifier extends AsyncNotifier<List<LeadModel>> {
  StreamSubscription<List<LeadModel>>? _subscription;

  @override
  Future<List<LeadModel>> build() {
    final first = Completer<List<LeadModel>>();

    _subscription?.cancel();
    _subscription = ref.read(leadRepositoryProvider).watchLiveLeads().listen(
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

  /// Manual refresh. The stream keeps the list current on its own; this exists
  /// for the pull-to-refresh gesture and to recover from a stream error.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(leadRepositoryProvider).getLiveLeads(),
    );
  }

  /// Claims a lead. Rethrows so the screen can show the collision message; the
  /// board itself needs no reconciliation here because the claim writes the
  /// lead out of the live query, and the stream removes the card.
  Future<LeadModel> claim(String leadId, String employeeId) async {
    final lead =
        await ref.read(leadRepositoryProvider).claimLead(leadId, employeeId);
    ref.bumpDataRevision();
    return lead;
  }
}

final liveLeadsProvider =
    AsyncNotifierProvider<LiveLeadsNotifier, List<LeadModel>>(
  LiveLeadsNotifier.new,
);

/// Free-text filter applied to the live board.
final liveLeadsQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final filteredLiveLeadsProvider =
    Provider.autoDispose<AsyncValue<List<LeadModel>>>((ref) {
  final query = ref.watch(liveLeadsQueryProvider);
  return ref.watch(liveLeadsProvider).whenData((leads) {
    if (query.isEmpty) return leads;
    return leads
        .where((l) =>
            l.name.containsIgnoreCase(query) ||
            (l.company?.containsIgnoreCase(query) ?? false) ||
            (l.location?.containsIgnoreCase(query) ?? false) ||
            (l.contactPerson?.containsIgnoreCase(query) ?? false) ||
            l.phone.contains(query))
        .toList(growable: false);
  });
});
