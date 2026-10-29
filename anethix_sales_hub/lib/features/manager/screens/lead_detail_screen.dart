import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/lead_sections.dart';
import '../../employee/providers/calling_provider.dart';
import '../../employee/providers/my_leads_provider.dart';
import '../../employee/screens/add_remark_screen.dart';
import '../../employee/widgets/my_lead_card.dart';
import '../providers/lead_management_provider.dart';
import '../widgets/employee_picker_sheet.dart';

/// Manager view of a lead: full history, priority control, no calling.
class LeadDetailScreen extends ConsumerStatefulWidget {
  const LeadDetailScreen({super.key, required this.leadId});

  final String leadId;

  @override
  ConsumerState<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends ConsumerState<LeadDetailScreen> {
  bool _isSavingPriority = false;
  bool _isAssigning = false;

  Future<void> _setPriority(LeadPriority priority) async {
    setState(() => _isSavingPriority = true);
    try {
      await ref
          .read(leadActionsProvider)
          .updatePriority(widget.leadId, priority);
      if (mounted) context.showInfo('Priority updated.');
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _isSavingPriority = false);
    }
  }

  /// Hands this one lead directly to a team member, bypassing the live board.
  Future<void> _assignToEmployee() async {
    final employeeId = await EmployeePickerSheet.show(context, leadCount: 1);
    if (employeeId == null || !mounted) return;

    final names = ref.read(employeeNamesProvider).valueOrNull ?? const {};
    final employeeName = names[employeeId] ?? 'this employee';

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Assign 1 lead to $employeeName?',
      message:
          'It goes straight to $employeeName as a claimed lead, without '
          'appearing on the live board.',
      confirmLabel: 'Assign',
      icon: Icons.person_add_alt_1_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isAssigning = true);
    try {
      await ref
          .read(managerLeadsProvider.notifier)
          .assignLeadsToEmployee(
            leadIds: [widget.leadId],
            employeeId: employeeId,
          );
      ref.invalidate(leadWorkspaceProvider(widget.leadId));
      if (mounted) context.showInfo('Lead assigned to $employeeName.');
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspaceAsync = ref.watch(leadWorkspaceProvider(widget.leadId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.invalidate(leadWorkspaceProvider(widget.leadId)),
          ),
        ],
      ),
      body: workspaceAsync.when(
        loading: () => const LoadingState(itemHeight: 150),
        error: (error, _) => ErrorState(
          message: ErrorState.describe(error),
          onRetry: () => ref.invalidate(leadWorkspaceProvider(widget.leadId)),
        ),
        data: (workspace) {
          final lead = workspace.lead;

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(leadWorkspaceProvider(widget.leadId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                32,
              ),
              children: [
                LeadHeaderCard(lead: lead),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pipeline',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          StatusBadge(status: lead.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      PipelineStepper(status: lead.status),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Priority',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (_isSavingPriority) const InlineSpinner(size: 16),
                        ],
                      ),
                      const SizedBox(height: 12),
                      PrioritySelector(
                        value: lead.priority,
                        onChanged: _isSavingPriority ? (_) {} : _setPriority,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _AssigneeCard(
                  employee: workspace.assignedEmployee,
                  claimedAt: lead.claimedAt,
                  isAvailable: lead.isAvailable,
                ),
                // Direct assignment is only offered while the lead is still
                // unclaimed — once a rep holds it, reassignment is not this
                // screen's job.
                if (lead.assignedEmployeeId == null &&
                    (lead.status == LeadStatus.draft ||
                        lead.status == LeadStatus.live)) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: _isAssigning ? null : _assignToEmployee,
                    icon: _isAssigning
                        ? const InlineSpinner(size: 16)
                        : const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Assign to Employee'),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    // The sheet marks these remarks as seen as it opens.
                    final saved = await AddRemarkSheet.show(
                      context,
                      leadId: lead.id,
                      leadName: lead.name,
                    );
                    if (saved && context.mounted) {
                      context.showInfo('Remark added.');
                    }
                  },
                  // The manager's remarks are already loaded with the lead, so
                  // the badge costs no extra query here.
                  icon: RemarkIndicator(
                    badge: remarkBadgeFor([
                      for (final r in workspace.remarks) r.createdAt,
                    ], ref.watch(remarkViewsProvider)[lead.id]),
                    child: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                  label: const Text('Add a remark'),
                ),
                const SectionHeader(title: 'Call history'),
                CallHistorySection(calls: workspace.calls),
                const SectionHeader(title: 'Remarks'),
                RemarksSection(remarks: workspace.remarks),
                const SectionHeader(title: 'Activity timeline'),
                ActivityTimeline(
                  activities: workspace.activities,
                  emptyMessage: 'Nothing has happened on this lead yet.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AssigneeCard extends StatelessWidget {
  const _AssigneeCard({
    required this.employee,
    required this.claimedAt,
    required this.isAvailable,
  });

  final UserModel? employee;
  final DateTime? claimedAt;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (employee == null) {
      return AppCard(
        child: Row(
          children: [
            Icon(
              isAvailable ? Icons.podcasts_rounded : Icons.person_off_outlined,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isAvailable
                    ? 'Live on the board, waiting to be claimed.'
                    : 'Not assigned to anyone yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Row(
        children: [
          InitialsAvatar(name: employee!.name, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assigned to', style: theme.textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(employee!.name, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Claimed ${AppDate.ago(claimedAt)}  ·  ${employee!.phone}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
