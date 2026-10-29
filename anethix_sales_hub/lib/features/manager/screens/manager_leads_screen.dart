import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/constants/lead_priority.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../shared/models/enums.dart';
import '../providers/lead_management_provider.dart';
import '../widgets/employee_picker_sheet.dart';
import '../widgets/lead_card.dart';
import '../widgets/make_live_fab.dart';

class ManagerLeadsScreen extends ConsumerStatefulWidget {
  const ManagerLeadsScreen({super.key});

  @override
  ConsumerState<ManagerLeadsScreen> createState() => _ManagerLeadsScreenState();
}

class _ManagerLeadsScreenState extends ConsumerState<ManagerLeadsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: ManagerLeadTab.values.length,
    vsync: this,
  )..addListener(_onTabChanged);

  bool _isSearching = false;
  bool _isPublishing = false;

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final tab = ManagerLeadTab.values[_tabController.index];
    ref.read(managerLeadTabProvider.notifier).state = tab;
    // Selection only makes sense on the Draft tab.
    if (tab != ManagerLeadTab.draft) {
      ref.read(draftSelectionProvider.notifier).state = {};
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _makeLive() async {
    final selection = ref.read(draftSelectionProvider);
    if (selection.isEmpty) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Publish ${selection.length} lead'
          '${selection.length == 1 ? '' : 's'}?',
      message: 'They will appear on the live board and any employee can '
          'claim them.',
      confirmLabel: 'Make live',
      icon: Icons.podcasts_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isPublishing = true);
    try {
      final count = await ref
          .read(managerLeadsProvider.notifier)
          .publish(selection.toList());
      ref.read(draftSelectionProvider.notifier).state = {};
      if (mounted) {
        context.showInfo('$count lead${count == 1 ? '' : 's'} are now live.');
      }
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  /// Direct assignment: pick a team member, confirm, then hand the selected
  /// drafts straight to them without going through the live board.
  Future<void> _assignToEmployee() async {
    final selection = ref.read(draftSelectionProvider);
    if (selection.isEmpty) return;

    final employeeId = await EmployeePickerSheet.show(
      context,
      leadCount: selection.length,
    );
    if (employeeId == null || !mounted) return;

    final names = ref.read(employeeNamesProvider).valueOrNull ?? const {};
    final employeeName = names[employeeId] ?? 'this employee';

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Assign ${selection.length} lead'
          '${selection.length == 1 ? '' : 's'} to $employeeName?',
      message: 'They go straight to $employeeName as claimed leads, without '
          'appearing on the live board.',
      confirmLabel: 'Assign',
      icon: Icons.person_add_alt_1_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isPublishing = true);
    try {
      final count =
          await ref.read(managerLeadsProvider.notifier).assignLeadsToEmployee(
                leadIds: selection.toList(),
                employeeId: employeeId,
              );
      ref.read(draftSelectionProvider.notifier).state = {};
      if (mounted) {
        context.showInfo(
          '$count lead${count == 1 ? '' : 's'} assigned to $employeeName.',
        );
      }
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _showFilterSheet() async {
    final current = ref.read(managerPriorityFilterProvider);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Filter by priority',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.clear_all_rounded),
              title: const Text('Any priority'),
              trailing: current == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () {
                ref.read(managerPriorityFilterProvider.notifier).state = null;
                Navigator.of(sheetContext).pop();
              },
            ),
            for (final priority in LeadPriority.values)
              ListTile(
                leading: Icon(priority.icon, color: priority.color),
                title: Text(priority.label),
                trailing: current == priority
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  ref.read(managerPriorityFilterProvider.notifier).state =
                      priority;
                  Navigator.of(sheetContext).pop();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(filteredManagerLeadsProvider);
    final tab = ref.watch(managerLeadTabProvider);
    final query = ref.watch(managerLeadQueryProvider);
    final priorityFilter = ref.watch(managerPriorityFilterProvider);
    final selection = ref.watch(draftSelectionProvider);
    final names = ref.watch(employeeNamesProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? AppSearchField(
                autofocus: true,
                hintText: 'Search name, company or phone',
                initialValue: query,
                onChanged: (value) =>
                    ref.read(managerLeadQueryProvider.notifier).state = value,
              )
            : const Text('Leads'),
        titleSpacing: _isSearching ? 8 : null,
        centerTitle: !_isSearching,
        actions: [
          IconButton(
            icon: Icon(_isSearching
                ? Icons.close_rounded
                : Icons.search_rounded),
            tooltip: _isSearching ? 'Close search' : 'Search',
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (!_isSearching) {
                ref.read(managerLeadQueryProvider.notifier).state = '';
              }
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: priorityFilter != null,
              child: const Icon(Icons.tune_rounded),
            ),
            tooltip: 'Filter',
            onPressed: _showFilterSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            for (final t in ManagerLeadTab.values) Tab(text: t.label),
          ],
        ),
      ),
      floatingActionButton: selection.isNotEmpty
          ? null
          : LeadSpeedDial(
              onAddLead: () => context.push(Routes.managerCreateLead),
              onImportLeads: () => context.push(Routes.managerImportLeads),
            ),
      bottomNavigationBar: selection.isEmpty
          ? null
          : MakeLiveBar(
              selectedCount: selection.length,
              isBusy: _isPublishing,
              onMakeLive: _makeLive,
              onAssign: _assignToEmployee,
              onClear: () =>
                  ref.read(draftSelectionProvider.notifier).state = {},
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(managerLeadsProvider.notifier).refresh(),
        child: leadsAsync.when(
          loading: () => const LoadingState(itemHeight: 150),
          error: (error, _) => ScrollableEmptyState(
            child: ErrorState(
              message: ErrorState.describe(error),
              onRetry: () => ref.read(managerLeadsProvider.notifier).refresh(),
            ),
          ),
          data: (leads) {
            if (leads.isEmpty) {
              return ScrollableEmptyState(
                child: EmptyState(
                  icon: Icons.workspaces_outline,
                  title: query.isNotEmpty
                      ? 'No leads match "$query"'
                      : 'Nothing in ${tab.label}',
                  message: tab == ManagerLeadTab.draft
                      ? 'Add a lead manually or import a sheet to get started.'
                      : 'Try another tab, or clear your filters.',
                  actionLabel:
                      tab == ManagerLeadTab.draft ? 'Add a lead' : null,
                  onAction: () => context.push(Routes.managerCreateLead),
                ),
              );
            }

            final isDraftTab = tab == ManagerLeadTab.draft;
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                selection.isEmpty ? 96 : 24,
              ),
              itemCount: leads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final lead = leads[index];
                return ManagerLeadCard(
                  lead: lead,
                  assigneeName: names[lead.assignedEmployeeId],
                  isSelectable: isDraftTab,
                  isSelected: selection.contains(lead.id),
                  onSelectedChanged: (selected) {
                    final next = {...selection};
                    selected ? next.add(lead.id) : next.remove(lead.id);
                    ref.read(draftSelectionProvider.notifier).state = next;
                  },
                  onTap: () => context.push(Routes.managerLead(lead.id)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
