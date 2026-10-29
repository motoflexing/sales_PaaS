import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../employee/providers/employee_follow_up_provider.dart';
import '../../employee/widgets/follow_up_card.dart';
import '../providers/lead_management_provider.dart';
import '../providers/team_provider.dart';

/// Read-only team-wide follow-up overview. Managers monitor; only the assigned
/// employee can complete or reschedule.
class ManagerFollowUpsScreen extends ConsumerStatefulWidget {
  const ManagerFollowUpsScreen({super.key});

  @override
  ConsumerState<ManagerFollowUpsScreen> createState() =>
      _ManagerFollowUpsScreenState();
}

class _ManagerFollowUpsScreenState extends ConsumerState<ManagerFollowUpsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: FollowUpTab.values.length, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(managerFollowUpBoardProvider);
    final board = boardAsync.valueOrNull;
    final names = ref.watch(employeeNamesProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team follow-ups'),
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
        loading: () => const LoadingState(itemHeight: 140),
        error: (error, _) => ErrorState(
          message: ErrorState.describe(error),
          onRetry: () => ref.invalidate(managerFollowUpBoardProvider),
        ),
        data: (data) => TabBarView(
          controller: _tabController,
          children: [
            for (final tab in FollowUpTab.values)
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(managerFollowUpBoardProvider);
                  await ref.read(managerFollowUpBoardProvider.future);
                },
                child: data.forTab(tab).isEmpty
                    ? ScrollableEmptyState(
                        child: EmptyState(
                          icon: tab == FollowUpTab.overdue
                              ? Icons.verified_rounded
                              : Icons.event_available_rounded,
                          title: 'Nothing in ${tab.label.toLowerCase()}',
                          message: tab == FollowUpTab.overdue
                              ? 'Your team is fully caught up.'
                              : 'Follow-ups your team schedules land here.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppConstants.pagePadding,
                          AppConstants.pagePadding,
                          AppConstants.pagePadding,
                          24,
                        ),
                        itemCount: data.forTab(tab).length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final entry = data.forTab(tab)[index];
                          return FollowUpCard(
                            entry: entry,
                            showActions: false,
                            ownerName: names[entry.followUp.employeeId],
                            onTap: entry.lead == null
                                ? null
                                : () => context.push(
                                      Routes.managerLead(entry.lead!.id),
                                    ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
