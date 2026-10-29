import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/lead_status.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/charts.dart';
import '../providers/admin_dashboard_provider.dart';

/// Report hub. Each card summarises a slice and links to the live view that
/// already renders it, rather than generating a separate document.
class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: dataAsync.when(
        loading: () => const LoadingState(itemHeight: 120),
        error: (error, _) => ErrorState(
          message: ErrorState.describe(error),
          onRetry: () => ref.invalidate(adminDashboardProvider),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminDashboardProvider);
            await ref.read(adminDashboardProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              AppConstants.pagePadding,
              AppConstants.pagePadding,
              32,
            ),
            children: [
              _ReportCard(
                icon: Icons.trending_up_rounded,
                title: 'Lead Conversion',
                statLabel: 'Conversion rate',
                statValue: '${data.conversionRate.toStringAsFixed(0)}%',
                caption: '${data.wonLeads} won  ·  ${data.lostLeads} lost  ·  '
                    '${data.totalLeads} total',
                accent: AppColors.success,
                actionLabel: 'View leads',
                onView: () => context.go(Routes.adminLeads),
              ),
              const SizedBox(height: 12),
              _ReportCard(
                icon: Icons.leaderboard_rounded,
                title: 'Employee Performance',
                statLabel: 'Top scorer',
                statValue: '${data.topPerformer?.score ?? 0}',
                caption: data.topPerformer == null
                    ? 'No scores recorded this month'
                    : '${data.topPerformer!.employeeName}  ·  '
                        '${data.topPerformers.length} ranked',
                actionLabel: 'View leaderboard',
                onView: () => context.push(Routes.adminLeaderboard),
              ),
              const SizedBox(height: 12),
              _ReportCard(
                icon: Icons.fact_check_rounded,
                title: 'Attendance Summary',
                statLabel: 'Checked in today',
                statValue: '${data.activeToday}',
                caption: 'Out of ${data.totalEmployees + data.totalManagers} '
                    'active staff',
                actionLabel: 'View attendance',
                onView: () => context.go(Routes.adminAttendance),
              ),
              const SizedBox(height: 12),
              _ReportCard(
                icon: Icons.phone_in_talk_rounded,
                title: 'Call Activity',
                statLabel: 'Calls today',
                statValue: '${data.callsToday}',
                caption: '${data.followUpsToday} follow-ups due  ·  '
                    '${data.overdueFollowUps} overdue',
                accent: data.overdueFollowUps > 0
                    ? Theme.of(context).colorScheme.error
                    : null,
                actionLabel: 'View dashboard',
                onView: () => context.go(Routes.adminDashboard),
              ),
              const SectionHeader(title: 'At a glance'),
              ChartCard(
                title: 'Pipeline distribution',
                caption: 'Where every lead is sitting right now',
                height: 190,
                child: HorizontalBarChart(
                  useDatumColors: true,
                  data: [
                    for (final status in LeadStatus.values)
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
                title: 'Conversions over time',
                caption: 'Leads marked won, last 30 days',
                height: 170,
                child: TrendLineChart(
                  data: [
                    for (final (day, count) in data.conversionsByDay)
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

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.statLabel,
    required this.statValue,
    required this.caption,
    required this.actionLabel,
    required this.onView,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String statLabel;
  final String statValue;
  final String caption;
  final String actionLabel;
  final VoidCallback onView;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = accent ?? scheme.primary;

    return AppCard(
      onTap: onView,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    statValue,
                    style: theme.textTheme.headlineSmall?.copyWith(color: tone),
                  ),
                  Text(
                    statLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onView,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
