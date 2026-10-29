import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../data/models/lead_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/shared_providers.dart';
import '../../auth/providers/auth_provider.dart';

enum ManagerLeadTab { draft, live, claimed, all }

extension ManagerLeadTabX on ManagerLeadTab {
  String get label => switch (this) {
        ManagerLeadTab.draft => 'Draft',
        ManagerLeadTab.live => 'Live',
        ManagerLeadTab.claimed => 'Claimed',
        ManagerLeadTab.all => 'All',
      };

  bool matches(LeadModel lead) => switch (this) {
        ManagerLeadTab.draft => lead.status == LeadStatus.draft,
        ManagerLeadTab.live => lead.isAvailable,
        ManagerLeadTab.claimed =>
          lead.assignedEmployeeId != null,
        ManagerLeadTab.all => true,
      };
}

/// Every lead this manager owns, newest activity first.
class ManagerLeadsNotifier extends AsyncNotifier<List<LeadModel>> {
  @override
  Future<List<LeadModel>> build() async {
    ref.watch(dataRevisionProvider);
    final user = ref.watch(authProvider);
    if (user == null) return const [];
    return ref.read(leadRepositoryProvider).getLeadsByManager(user.id);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  /// Publishes the selected drafts. Returns how many went live.
  Future<int> publish(List<String> leadIds) async {
    final user = ref.read(authProvider);
    if (user == null) return 0;
    final count =
        await ref.read(leadRepositoryProvider).publishLeads(leadIds, user.id);
    ref.bumpDataRevision();
    return count;
  }

  /// Assigns the given leads directly to one employee, bypassing the live
  /// board. Returns how many were handed over.
  Future<int> assignLeadsToEmployee({
    required List<String> leadIds,
    required String employeeId,
  }) async {
    final user = ref.read(authProvider);
    if (user == null) return 0;
    await ref.read(leadRepositoryProvider).assignLeadsToEmployee(
          leadIds: leadIds,
          employeeId: employeeId,
          managerId: user.id,
        );
    // Bumping the revision is what refreshes this list (build watches it) and
    // every other view of the same leads.
    ref.bumpDataRevision();
    return leadIds.length;
  }

  Future<void> updatePriority(String leadId, LeadPriority priority) async {
    final user = ref.read(authProvider);
    if (user == null) return;
    await ref
        .read(leadRepositoryProvider)
        .updatePriority(leadId, priority, user.id);
    ref.bumpDataRevision();
  }
}

final managerLeadsProvider =
    AsyncNotifierProvider<ManagerLeadsNotifier, List<LeadModel>>(
  ManagerLeadsNotifier.new,
);

final managerLeadTabProvider =
    StateProvider.autoDispose<ManagerLeadTab>((ref) => ManagerLeadTab.draft);

final managerLeadQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Null means "any priority".
final managerPriorityFilterProvider =
    StateProvider.autoDispose<LeadPriority?>((ref) => null);

/// Ids ticked in the Draft tab, ready to go live.
final draftSelectionProvider =
    StateProvider.autoDispose<Set<String>>((ref) => <String>{});

final filteredManagerLeadsProvider =
    Provider.autoDispose<AsyncValue<List<LeadModel>>>((ref) {
  final tab = ref.watch(managerLeadTabProvider);
  final query = ref.watch(managerLeadQueryProvider);
  final priority = ref.watch(managerPriorityFilterProvider);

  return ref.watch(managerLeadsProvider).whenData((leads) {
    return leads.where((lead) {
      if (!tab.matches(lead)) return false;
      if (priority != null && lead.priority != priority) return false;
      if (query.isEmpty) return true;
      return lead.name.containsIgnoreCase(query) ||
          (lead.company?.containsIgnoreCase(query) ?? false) ||
          lead.phone.contains(query);
    }).toList(growable: false);
  });
});

/// Employee id to display name, for showing who holds a claimed lead.
final employeeNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  ref.watch(dataRevisionProvider);
  final users = await ref.read(userRepositoryProvider).getAllUsers();
  return {for (final u in users) u.id: u.name};
});
