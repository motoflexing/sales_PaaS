import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../data/models/lead_model.dart';
import '../../../shared/widgets/charts.dart';
import '../../../shared/widgets/lead_sections.dart';
import '../providers/team_provider.dart';

class EmployeePerformanceScreen extends ConsumerWidget {
  const EmployeePerformanceScreen({super.key, required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(employeePerformanceProvider(employeeId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: dataAsync.when(
        loading: () => const LoadingState(itemHeight: 130),
        error: (error, _) => ErrorState(
          message: ErrorState.describe(error),
          onRetry: () =>
              ref.invalidate(employeePerformanceProvider(employeeId)),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(employeePerformanceProvider(employeeId));
            await ref.read(employeePerformanceProvider(employeeId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              AppConstants.pagePadding,
              AppConstants.pagePadding,
              32,
            ),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        InitialsAvatar(name: data.user.name, radius: 26),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.user.name,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                data.rank > 0
                                    ? 'Rank #${data.rank}  ·  '
                                        '${data.score} points'
                                    : '${data.score} points',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    DetailRow(
                      icon: Icons.alternate_email_rounded,
                      label: 'Email',
                      value: data.user.email,
                    ),
                    DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: data.user.phone,
                    ),
                    DetailRow(
                      icon: Icons.badge_outlined,
                      label: 'Joined',
                      value: AppDate.day(data.user.joinDate),
                    ),
                    DetailRow(
                      icon: Icons.fact_check_outlined,
                      label: 'Attendance (30 days)',
                      value: '${data.attendanceDays} days',
                    ),
                  ],
                ),
              ),
              if (data.overdueFollowUps > 0 || data.stuckLeads.isNotEmpty) ...[
                const SizedBox(height: 12),
                _HighlightsCard(
                  overdueFollowUps: data.overdueFollowUps,
                  stuckLeads: data.stuckLeads.length,
                ),
              ],
              const SectionHeader(title: 'Numbers'),
              StatGrid(
                crossAxisCount: 4,
                childAspectRatio: 0.95,
                tiles: [
                  StatTile(
                    label: 'Leads',
                    value: '${data.leads.length}',
                  ),
                  StatTile(label: 'Calls', value: '${data.totalCalls}'),
                  StatTile(
                    label: 'Connected',
                    value: '${data.connectedCalls}',
                  ),
                  StatTile(
                    label: 'Follow-ups',
                    value: '${data.followUpsCompleted}',
                  ),
                  StatTile(label: 'Meetings', value: '${data.meetings}'),
                  StatTile(
                    label: 'Won',
                    value: '${data.won}',
                    accent: AppColors.success,
                  ),
                  StatTile(
                    label: 'Lost',
                    value: '${data.lost}',
                    accent: theme.colorScheme.error,
                  ),
                  StatTile(
                    label: 'Score',
                    value: '${data.score}',
                    accent: theme.colorScheme.primary,
                  ),
                ],
              ),
              const SectionHeader(title: 'Activity'),
              ChartCard(
                title: 'Calls by day',
                caption: 'Last 7 days',
                height: 170,
                child: SimpleBarChart(
                  data: [
                    for (final (day, count) in data.callsByDay)
                      ChartDatum(
                        label: AppDate.chartLabel(day),
                        value: count.toDouble(),
                      ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Current leads'),
              if (data.leads.isEmpty)
                AppCard(
                  child: Text(
                    'No leads assigned yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < data.leads.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _LeadRow(lead: data.leads[i]),
                      ],
                    ],
                  ),
                ),
              const SectionHeader(title: 'Recent activity'),
              ActivityTimeline(
                activities: data.recentActivity,
                showAuthor: false,
                emptyMessage: 'No recorded activity in this period.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadRow extends StatelessWidget {
  const _LeadRow({required this.lead});

  final LeadModel lead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/manager/leads/${lead.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead.name,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (lead.company != null)
                    Text(
                      lead.company!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StatusBadge(status: lead.status, compact: true),
          ],
        ),
      ),
    );
  }
}

class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({
    required this.overdueFollowUps,
    required this.stuckLeads,
  });

  final int overdueFollowUps;
  final int stuckLeads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      color: scheme.errorContainer.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.priority_high_rounded, color: scheme.error, size: 20),
              const SizedBox(width: 8),
              Text('Needs attention', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          if (overdueFollowUps > 0)
            Text(
              '· $overdueFollowUps overdue follow-up'
              '${overdueFollowUps == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall,
            ),
          if (stuckLeads > 0)
            Text(
              '· $stuckLeads lead${stuckLeads == 1 ? '' : 's'} with no '
              'activity for ${AppConstants.stuckLeadDays}+ days',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
