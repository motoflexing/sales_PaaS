import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/lead_status.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../data/models/lead_model.dart';
import '../../../shared/providers/shared_providers.dart';
import '../providers/calling_provider.dart';
import '../providers/my_leads_provider.dart';
import '../screens/add_remark_screen.dart';
import '../screens/call_log_screen.dart';
import '../widgets/my_lead_card.dart';

/// Last-call and next-follow-up dates for the employee's leads, fetched once
/// so each card does not need its own round trip.
final _leadTimelineProvider =
    FutureProvider.autoDispose<Map<String, (DateTime?, DateTime?)>>((
      ref,
    ) async {
      ref.watch(dataRevisionProvider);
      final leads = await ref.watch(myLeadsProvider.future);
      if (leads.isEmpty) return const {};

      final employeeId = leads.first.assignedEmployeeId;
      if (employeeId == null) return const {};

      final calls = await ref
          .read(callLogRepositoryProvider)
          .getByEmployee(employeeId);
      final followUps = await ref
          .read(followUpRepositoryProvider)
          .getByEmployee(employeeId);

      final lastCall = <String, DateTime>{};
      for (final call in calls) {
        final existing = lastCall[call.leadId];
        if (existing == null || call.date.isAfter(existing)) {
          lastCall[call.leadId] = call.date;
        }
      }

      final nextFollowUp = <String, DateTime>{};
      for (final followUp in followUps.where((f) => f.isOpen)) {
        final existing = nextFollowUp[followUp.leadId];
        if (existing == null || followUp.scheduledAt.isBefore(existing)) {
          nextFollowUp[followUp.leadId] = followUp.scheduledAt;
        }
      }

      return {
        for (final lead in leads)
          lead.id: (lastCall[lead.id], nextFollowUp[lead.id]),
      };
    });

class MyLeadsScreen extends ConsumerStatefulWidget {
  const MyLeadsScreen({super.key});

  @override
  ConsumerState<MyLeadsScreen> createState() => _MyLeadsScreenState();
}

class _MyLeadsScreenState extends ConsumerState<MyLeadsScreen> {
  bool _isSearching = false;

  Future<void> _call(LeadModel lead) async {
    final launched = await ref.read(leadActionsProvider).dial(lead.phone);
    if (!mounted) return;
    if (!launched) {
      context.showError('No dialer app is available on this device.');
    }
    // Whether or not the dialer opened, offer to record the outcome.
    final saved = await CallLogSheet.show(context, lead);
    if (saved && mounted) context.showInfo('Call logged.');
  }

  Future<void> _remark(LeadModel lead) async {
    // The sheet marks the lead's remarks as seen as it opens.
    final saved = await AddRemarkSheet.show(
      context,
      leadId: lead.id,
      leadName: lead.name,
    );
    if (saved && mounted) context.showInfo('Remark added.');
  }

  Future<void> _status(LeadModel lead) async {
    final saved = await StatusUpdateSheet.show(
      context,
      leadId: lead.id,
      current: lead.status,
      allowed: allowedNextStatuses(lead.status).toList(),
    );
    if (saved && mounted) context.showInfo('Status updated.');
  }

  Future<void> _followUp(LeadModel lead) async {
    final saved = await ScheduleFollowUpSheet.show(
      context,
      leadId: lead.id,
      leadName: lead.name,
    );
    if (saved && mounted) context.showInfo('Follow-up scheduled.');
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(filteredMyLeadsProvider);
    final filter = ref.watch(myLeadsFilterProvider);
    final query = ref.watch(myLeadsQueryProvider);
    final timeline = ref.watch(_leadTimelineProvider).valueOrNull ?? const {};
    final remarkBadges = ref.watch(leadRemarkBadgesProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? AppSearchField(
                autofocus: true,
                hintText: 'Search name, company or phone',
                initialValue: query,
                onChanged: (value) =>
                    ref.read(myLeadsQueryProvider.notifier).state = value,
              )
            : const Text('My Leads'),
        titleSpacing: _isSearching ? 8 : null,
        centerTitle: !_isSearching,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
            ),
            tooltip: _isSearching ? 'Close search' : 'Search',
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (!_isSearching) {
                ref.read(myLeadsQueryProvider.notifier).state = '';
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: FilterChipRow<MyLeadsFilter>(
              values: MyLeadsFilter.values,
              selected: filter,
              labelBuilder: (value) => value.label,
              onSelected: (value) =>
                  ref.read(myLeadsFilterProvider.notifier).state = value,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myLeadsProvider.notifier).refresh(),
        child: leadsAsync.when(
          loading: () => const LoadingState(itemHeight: 180),
          error: (error, _) => ScrollableEmptyState(
            child: ErrorState(
              message: ErrorState.describe(error),
              onRetry: () => ref.read(myLeadsProvider.notifier).refresh(),
            ),
          ),
          data: (leads) {
            if (leads.isEmpty) {
              return ScrollableEmptyState(
                child: EmptyState(
                  icon: Icons.folder_open_rounded,
                  title: query.isNotEmpty
                      ? 'No leads match "$query"'
                      : filter == MyLeadsFilter.all
                      ? 'You have not claimed any leads yet'
                      : 'Nothing in ${filter.label}',
                  message: filter == MyLeadsFilter.all && query.isEmpty
                      ? 'Head to Live Leads and claim one to get started.'
                      : 'Try a different filter or search term.',
                  actionLabel: filter == MyLeadsFilter.all && query.isEmpty
                      ? 'Browse live leads'
                      : null,
                  onAction: () => context.go(Routes.employeeLiveLeads),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                12,
                AppConstants.pagePadding,
                24,
              ),
              itemCount: leads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final lead = leads[index];
                final dates = timeline[lead.id];
                return MyLeadCard(
                  lead: lead,
                  lastCallAt: dates?.$1,
                  nextFollowUpAt: dates?.$2,
                  remarkBadge: remarkBadges[lead.id],
                  onTap: () => context.push(Routes.employeeLead(lead.id)),
                  onCall: () => _call(lead),
                  onRemark: () => _remark(lead),
                  onStatus: () => _status(lead),
                  onFollowUp: () => _followUp(lead),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
