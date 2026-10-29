import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/lead_status.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/lead_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/lead_sections.dart';
import '../providers/calling_provider.dart';
import '../providers/my_leads_provider.dart';
import 'add_remark_screen.dart';
import 'call_log_screen.dart';

/// Single-lead workspace: call, log outcomes, add remarks, move the stage.
class LeadWorkScreen extends ConsumerWidget {
  const LeadWorkScreen({super.key, required this.leadId});

  final String leadId;

  Future<void> _call(
    BuildContext context,
    WidgetRef ref,
    LeadModel lead, {
    String? number,
  }) async {
    final launched = await ref
        .read(leadActionsProvider)
        .dial(number ?? lead.phone);
    if (!context.mounted) return;
    if (!launched) {
      context.showError('No dialer app is available on this device.');
    }
    final saved = await CallLogSheet.show(context, lead);
    if (saved && context.mounted) context.showInfo('Call logged.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceAsync = ref.watch(leadWorkspaceProvider(leadId));

    // Reaching this screen means reading the lead's remarks, so the unread
    // badge on My Leads clears.
    return _MarkRemarksViewed(
      leadId: leadId,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lead workspace'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(leadWorkspaceProvider(leadId)),
            ),
          ],
        ),
        body: workspaceAsync.when(
          loading: () => const LoadingState(itemHeight: 150),
          error: (error, _) => ErrorState(
            message: ErrorState.describe(error),
            onRetry: () => ref.invalidate(leadWorkspaceProvider(leadId)),
          ),
          data: (workspace) {
            final lead = workspace.lead;
            final nextStatuses = allowedNextStatuses(lead.status).toList();

            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(leadWorkspaceProvider(leadId)),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.pagePadding,
                  AppConstants.pagePadding,
                  AppConstants.pagePadding,
                  32,
                ),
                children: [
                  LeadHeaderCard(
                    lead: lead,
                    onCallPrimary: () => _call(context, ref, lead),
                    onCallAlternate: lead.alternatePhone == null
                        ? null
                        : () => _call(
                            context,
                            ref,
                            lead,
                            number: lead.alternatePhone,
                          ),
                  ),
                  const SizedBox(height: 16),
                  _QuickActions(
                    lead: lead,
                    onCall: () => _call(context, ref, lead),
                  ),
                  const SizedBox(height: 16),
                  if (lead.managerRemark != null) ...[
                    ManagerNoteCard(note: lead.managerRemark!),
                    const SizedBox(height: 16),
                  ],
                  _PipelineCard(lead: lead, nextStatuses: nextStatuses),
                  if (workspace.nextFollowUp != null) ...[
                    const SizedBox(height: 16),
                    _NextFollowUpCard(
                      scheduledAt: workspace.nextFollowUp!.scheduledAt,
                    ),
                  ],
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
      ),
    );
  }
}

/// Records that this lead's remarks have been seen, once, when the screen
/// mounts. Renders nothing of its own.
class _MarkRemarksViewed extends ConsumerStatefulWidget {
  const _MarkRemarksViewed({required this.leadId, required this.child});

  final String leadId;
  final Widget child;

  @override
  ConsumerState<_MarkRemarksViewed> createState() => _MarkRemarksViewedState();
}

class _MarkRemarksViewedState extends ConsumerState<_MarkRemarksViewed> {
  @override
  void initState() {
    super.initState();
    // After the first frame: marking updates a provider, which must not happen
    // while this widget is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(remarkViewsProvider.notifier).markViewed(widget.leadId);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.lead, required this.onCall});

  final LeadModel lead;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.phone_rounded),
              label: const Text('CALL'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () async {
                final saved = await AddRemarkSheet.show(
                  context,
                  leadId: lead.id,
                  leadName: lead.name,
                );
                if (saved && context.mounted) context.showInfo('Remark added.');
              },
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () async {
                final saved = await ScheduleFollowUpSheet.show(
                  context,
                  leadId: lead.id,
                  leadName: lead.name,
                );
                if (saved && context.mounted) {
                  context.showInfo('Follow-up scheduled.');
                }
              },
              child: const Icon(Icons.event_available_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.lead, required this.nextStatuses});

  final LeadModel lead;
  final List<LeadStatus> nextStatuses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pipeline stage',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (nextStatuses.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final saved = await StatusUpdateSheet.show(
                      context,
                      leadId: lead.id,
                      current: lead.status,
                      allowed: nextStatuses,
                    );
                    if (saved && context.mounted) {
                      context.showInfo('Status updated.');
                    }
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Update'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          PipelineStepper(status: lead.status),
        ],
      ),
    );
  }
}

class _NextFollowUpCard extends StatelessWidget {
  const _NextFollowUpCard({required this.scheduledAt});

  final DateTime scheduledAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOverdue = scheduledAt.isBefore(DateTime.now());
    final tone = isOverdue ? scheme.error : scheme.primary;

    return AppCard(
      borderColor: tone.withValues(alpha: 0.35),
      child: Row(
        children: [
          Icon(Icons.event_rounded, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next follow-up', style: theme.textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(
                  isOverdue
                      ? AppDate.overdueBy(scheduledAt)
                      : AppDate.relativeSlot(scheduledAt),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w600,
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
