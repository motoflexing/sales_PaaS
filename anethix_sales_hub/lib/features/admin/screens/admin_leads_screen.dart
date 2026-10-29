import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/lead_status.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/lead_model.dart';
import '../../../shared/widgets/lead_sections.dart';
import '../../../shared/models/enums.dart';
import '../../manager/providers/lead_management_provider.dart';
import '../../manager/widgets/lead_card.dart';
import '../providers/user_management_provider.dart';

/// Company-wide, read-only lead browser for admins.
class AdminLeadsScreen extends ConsumerStatefulWidget {
  const AdminLeadsScreen({super.key});

  @override
  ConsumerState<AdminLeadsScreen> createState() => _AdminLeadsScreenState();
}

class _AdminLeadsScreenState extends ConsumerState<AdminLeadsScreen> {
  bool _isSearching = false;

  Future<void> _showStatusFilter() async {
    final current = ref.read(adminLeadStatusFilterProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Filter by status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  ListTile(
                    leading: const Icon(Icons.clear_all_rounded),
                    title: const Text('Any status'),
                    trailing:
                        current == null ? const Icon(Icons.check_rounded) : null,
                    onTap: () {
                      ref
                          .read(adminLeadStatusFilterProvider.notifier)
                          .state = null;
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                  for (final status in LeadStatus.values)
                    ListTile(
                      leading: Icon(status.icon, color: status.color),
                      title: Text(status.label),
                      trailing: current == status
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () {
                        ref
                            .read(adminLeadStatusFilterProvider.notifier)
                            .state = status;
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Admins audit rather than work leads, so tapping opens a read-only sheet
  /// instead of the manager's editable detail screen.
  Future<void> _showLeadSheet(LeadModel lead) async {
    final assignee = ref.read(employeeNamesProvider).valueOrNull?[
        lead.assignedEmployeeId];

    await AppBottomSheet.showDraggable<void>(
      context,
      title: lead.name,
      subtitle: lead.company,
      builder: (controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppConstants.pagePadding,
          16,
          AppConstants.pagePadding,
          32,
        ),
        children: [
          PipelineStepper(status: lead.status),
          const SizedBox(height: 16),
          LeadHeaderCard(lead: lead),
          const SizedBox(height: 12),
          if (assignee != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Assigned to'),
              subtitle: Text(assignee),
            ),
          if (lead.managerRemark != null) ManagerNoteCard(note: lead.managerRemark!),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(filteredAdminLeadsProvider);
    final query = ref.watch(adminLeadQueryProvider);
    final status = ref.watch(adminLeadStatusFilterProvider);
    final names = ref.watch(employeeNamesProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? AppSearchField(
                autofocus: true,
                hintText: 'Search name, company or phone',
                initialValue: query,
                onChanged: (value) =>
                    ref.read(adminLeadQueryProvider.notifier).state = value,
              )
            : const Text('All leads'),
        titleSpacing: _isSearching ? 8 : null,
        centerTitle: !_isSearching,
        actions: [
          IconButton(
            icon:
                Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _isSearching ? 'Close search' : 'Search',
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (!_isSearching) {
                ref.read(adminLeadQueryProvider.notifier).state = '';
              }
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: status != null,
              child: const Icon(Icons.tune_rounded),
            ),
            tooltip: 'Filter by status',
            onPressed: _showStatusFilter,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminLeadsProvider);
          await ref.read(adminLeadsProvider.future);
        },
        child: leadsAsync.when(
          loading: () => const LoadingState(itemHeight: 150),
          error: (error, _) => ScrollableEmptyState(
            child: ErrorState(
              message: ErrorState.describe(error),
              onRetry: () => ref.invalidate(adminLeadsProvider),
            ),
          ),
          data: (leads) {
            if (leads.isEmpty) {
              return ScrollableEmptyState(
                child: EmptyState(
                  icon: Icons.workspaces_outline,
                  title: query.isNotEmpty
                      ? 'No leads match "$query"'
                      : 'No leads to show',
                  message: status != null
                      ? 'Nothing is sitting in ${status.label} right now.'
                      : 'Leads created by your managers will appear here.',
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                24,
              ),
              itemCount: leads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => ManagerLeadCard(
                lead: leads[index],
                assigneeName: names[leads[index].assignedEmployeeId],
                onTap: () => _showLeadSheet(leads[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}
