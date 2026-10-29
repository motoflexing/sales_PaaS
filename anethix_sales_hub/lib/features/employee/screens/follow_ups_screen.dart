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
import '../providers/calling_provider.dart';
import '../providers/employee_follow_up_provider.dart';
import '../screens/add_remark_screen.dart';
import '../screens/call_log_screen.dart';
import '../widgets/follow_up_card.dart';
import '../widgets/follow_up_date_picker.dart';

class FollowUpsScreen extends ConsumerStatefulWidget {
  const FollowUpsScreen({super.key});

  @override
  ConsumerState<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends ConsumerState<FollowUpsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: FollowUpTab.values.length, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _complete(FollowUpWithLead entry) async {
    final remark = await PromptDialog.show(
      context,
      title: 'Mark follow-up as completed?',
      message: entry.lead == null
          ? null
          : 'Lead: ${entry.lead!.name}',
      hintText: 'Outcome note (optional)',
      confirmLabel: 'Complete',
    );
    if (remark == null || !mounted) return;

    try {
      await ref
          .read(employeeFollowUpProvider.notifier)
          .complete(entry.followUp.id, remark: remark);
      if (mounted) context.showInfo('Follow-up completed.');
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    }
  }

  Future<void> _reschedule(FollowUpWithLead entry) async {
    final picked = await pickFollowUpDateTime(
      context,
      initial: entry.followUp.scheduledAt,
      helpText: 'Reschedule follow-up',
    );
    if (picked == null || !mounted) return;

    try {
      await ref
          .read(employeeFollowUpProvider.notifier)
          .reschedule(entry.followUp.id, picked);
      if (mounted) context.showInfo('Follow-up rescheduled.');
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    }
  }

  Future<void> _call(FollowUpWithLead entry) async {
    final lead = entry.lead;
    if (lead == null) return;
    final launched = await ref.read(leadActionsProvider).dial(lead.phone);
    if (!mounted) return;
    if (!launched) {
      context.showError('No dialer app is available on this device.');
    }
    final saved = await CallLogSheet.show(context, lead);
    if (saved && mounted) context.showInfo('Call logged.');
  }

  Future<void> _remark(FollowUpWithLead entry) async {
    final lead = entry.lead;
    if (lead == null) return;
    final saved = await AddRemarkSheet.show(
      context,
      leadId: lead.id,
      leadName: lead.name,
    );
    if (saved && mounted) context.showInfo('Remark added.');
  }

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(employeeFollowUpProvider);
    final board = boardAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-ups'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final tab in FollowUpTab.values)
              Tab(
                text: board == null
                    ? tab.label
                    : '${tab.label} (${board.forTab(tab).length})',
              ),
          ],
        ),
      ),
      body: boardAsync.when(
        loading: () => const LoadingState(itemHeight: 160),
        error: (error, _) => ErrorState(
          message: ErrorState.describe(error),
          onRetry: () => ref.read(employeeFollowUpProvider.notifier).refresh(),
        ),
        data: (data) => TabBarView(
          controller: _tabController,
          children: [
            for (final tab in FollowUpTab.values)
              _FollowUpList(
                tab: tab,
                entries: data.forTab(tab),
                onRefresh: () =>
                    ref.read(employeeFollowUpProvider.notifier).refresh(),
                onComplete: _complete,
                onReschedule: _reschedule,
                onCall: _call,
                onRemark: _remark,
              ),
          ],
        ),
      ),
    );
  }
}

class _FollowUpList extends StatelessWidget {
  const _FollowUpList({
    required this.tab,
    required this.entries,
    required this.onRefresh,
    required this.onComplete,
    required this.onReschedule,
    required this.onCall,
    required this.onRemark,
  });

  final FollowUpTab tab;
  final List<FollowUpWithLead> entries;
  final Future<void> Function() onRefresh;
  final void Function(FollowUpWithLead) onComplete;
  final void Function(FollowUpWithLead) onReschedule;
  final void Function(FollowUpWithLead) onCall;
  final void Function(FollowUpWithLead) onRemark;

  String get _emptyTitle => switch (tab) {
        FollowUpTab.today => 'Nothing due today',
        FollowUpTab.upcoming => 'No upcoming follow-ups',
        FollowUpTab.overdue => 'Nothing is overdue',
        FollowUpTab.completed => 'No completed follow-ups yet',
      };

  String get _emptyMessage => switch (tab) {
        FollowUpTab.today => 'Your day is clear. Claim a lead or work your pipeline.',
        FollowUpTab.upcoming => 'Schedule one from a lead to plan ahead.',
        FollowUpTab.overdue => 'Nicely done - you are fully caught up.',
        FollowUpTab.completed => 'Completed follow-ups will collect here.',
      };

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: entries.isEmpty
          ? ScrollableEmptyState(
              child: EmptyState(
                icon: tab == FollowUpTab.overdue
                    ? Icons.verified_rounded
                    : Icons.event_available_rounded,
                title: _emptyTitle,
                message: _emptyMessage,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                24,
              ),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return FollowUpCard(
                  entry: entry,
                  showActions: tab != FollowUpTab.completed,
                  onTap: entry.lead == null
                      ? null
                      : () => context.push(
                            Routes.employeeLead(entry.lead!.id),
                          ),
                  onCall: entry.lead == null ? null : () => onCall(entry),
                  onComplete: () => onComplete(entry),
                  onReschedule: () => onReschedule(entry),
                  onRemark: entry.lead == null ? null : () => onRemark(entry),
                );
              },
            ),
    );
  }
}
