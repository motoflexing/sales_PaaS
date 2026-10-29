import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/lead_status.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/charts.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/manager_dashboard_provider.dart';

class ManagerDashboardScreen extends ConsumerWidget {
  const ManagerDashboardScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to manage your team.',
      confirmLabel: 'Sign out',
      isDestructive: true,
      icon: Icons.logout_rounded,
    );
    if (confirmed) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final dataAsync = ref.watch(managerDashboardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppDate.greeting(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text('Dashboard', style: theme.textTheme.titleLarge),
          ],
        ),
        actions: [
          _NotificationBell(
            count: dataAsync.valueOrNull?.followUpsOverdue ?? 0,
            onTap: () => context.go(Routes.managerFollowUps),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => _logout(context, ref),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: InitialsAvatar(name: user?.name ?? '?', radius: 18),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const LoadingGridState(),
        error: (error, _) => ErrorState(
          message: ErrorState.describe(error),
          onRetry: () => ref.invalidate(managerDashboardProvider),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(managerDashboardProvider);
            await ref.read(managerDashboardProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              AppConstants.pagePadding,
              AppConstants.pagePadding,
              32,
            ),
            children: [
              const SectionHeader(title: 'Leads', padding: EdgeInsets.only(bottom: 8)),
              StatGrid(
                tiles: [
                  StatTile(
                    label: 'Total Leads',
                    value: '${data.totalLeads}',
                    icon: Icons.workspaces_rounded,
                  ),
                  StatTile(
                    label: 'New (7 days)',
                    value: '${data.newLeads}',
                    icon: Icons.fiber_new_rounded,
                  ),
                  StatTile(
                    label: 'Live Leads',
                    value: '${data.liveLeads}',
                    icon: Icons.podcasts_rounded,
                    accent: LeadStatus.live.color,
                  ),
                  StatTile(
                    label: 'Available',
                    value: '${data.availableLeads}',
                    icon: Icons.inventory_2_outlined,
                  ),
                  StatTile(
                    label: 'Claimed',
                    value: '${data.claimedLeads}',
                    icon: Icons.how_to_reg_rounded,
                    accent: LeadStatus.claimed.color,
                  ),
                  StatTile(
                    label: 'Contacted',
                    value: '${data.contactedLeads}',
                    icon: Icons.phone_in_talk_rounded,
                    accent: LeadStatus.contacted.color,
                  ),
                ],
              ),
              const SectionHeader(title: 'Follow-ups'),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Due today',
                      value: '${data.followUpsDue}',
                      icon: Icons.event_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'Overdue',
                      value: '${data.followUpsOverdue}',
                      icon: Icons.warning_amber_rounded,
                      accent: data.followUpsOverdue > 0
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'Completed',
                      value: '${data.followUpsCompleted}',
                      icon: Icons.task_alt_rounded,
                      accent: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SectionHeader(title: 'Conversion'),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Won',
                      value: '${data.wonLeads}',
                      icon: Icons.emoji_events_rounded,
                      accent: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'Lost',
                      value: '${data.lostLeads}',
                      icon: Icons.cancel_rounded,
                      accent: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'Conversion',
                      value: '${data.conversionRate.toStringAsFixed(0)}%',
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                ],
              ),
              const SectionHeader(title: 'Team today'),
              AppCard(
                onTap: () => context.go(Routes.managerTeam),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.groups_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${data.teamSize} team member'
                            '${data.teamSize == 1 ? '' : 's'}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    const Divider(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: MiniStat(
                            label: 'Calls today',
                            value: '${data.callsToday}',
                          ),
                        ),
                        Expanded(
                          child: MiniStat(
                            label: 'Claimed today',
                            value: '${data.claimedToday}',
                          ),
                        ),
                        Expanded(
                          child: MiniStat(
                            label: 'Meetings',
                            value: '${data.meetings}',
                          ),
                        ),
                        Expanded(
                          child: MiniStat(
                            label: 'Team score',
                            value: '${data.teamScore}',
                            accent: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Trends'),
              ChartCard(
                title: 'Leads by stage',
                caption: 'Across every lead you own',
                height: 200,
                child: HorizontalBarChart(
                  useDatumColors: true,
                  data: [
                    for (final status in pipelineStages.skip(1))
                      if ((data.leadsByStatus[status] ?? 0) > 0)
                        ChartDatum(
                          label: status.label,
                          value: (data.leadsByStatus[status] ?? 0).toDouble(),
                          color: status.color,
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ChartCard(
                title: 'Calls by day',
                caption: 'Last 7 days, whole team',
                height: 180,
                child: TrendLineChart(
                  data: [
                    for (final (day, count) in data.callsByDay)
                      ChartDatum(
                        label: AppDate.chartLabel(day),
                        value: count.toDouble(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: count == 0 ? 'Notifications' : '$count overdue follow-ups',
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: scheme.error,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
