import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/stat_tile.dart';
import '../providers/admin_dashboard_provider.dart';

/// Horizontally scrollable headcount strip.
class HeadcountStrip extends StatelessWidget {
  const HeadcountStrip({super.key, required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            width: 160,
            child: StatTile(
              label: 'Employees',
              value: '${data.totalEmployees}',
              icon: Icons.people_rounded,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 160,
            child: StatTile(
              label: 'Managers',
              value: '${data.totalManagers}',
              icon: Icons.supervisor_account_rounded,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 160,
            child: StatTile(
              label: 'Active today',
              value: '${data.activeToday}',
              icon: Icons.bolt_rounded,
              accent: AppColors.success,
              caption: 'Checked in',
            ),
          ),
        ],
      ),
    );
  }
}

class AdminLeadStatsGrid extends StatelessWidget {
  const AdminLeadStatsGrid({super.key, required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    return StatGrid(
      tiles: [
        StatTile(
          label: 'Total Leads',
          value: '${data.totalLeads}',
          icon: Icons.workspaces_rounded,
        ),
        StatTile(
          label: 'Live',
          value: '${data.liveLeads}',
          icon: Icons.podcasts_rounded,
        ),
        StatTile(
          label: 'Claimed',
          value: '${data.claimedLeads}',
          icon: Icons.how_to_reg_rounded,
        ),
        StatTile(
          label: 'Won',
          value: '${data.wonLeads}',
          icon: Icons.emoji_events_rounded,
          accent: AppColors.success,
        ),
        StatTile(
          label: 'Lost',
          value: '${data.lostLeads}',
          icon: Icons.cancel_rounded,
          accent: Theme.of(context).colorScheme.error,
        ),
        StatTile(
          label: 'Conversion',
          value: '${data.conversionRate.toStringAsFixed(0)}%',
          icon: Icons.trending_up_rounded,
        ),
      ],
    );
  }
}

class TopPerformerCard extends StatelessWidget {
  const TopPerformerCard({super.key, required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = data.topPerformer;

    if (top == null) {
      return AppCard(
        child: Text(
          'No scores recorded this month yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return AppCard(
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top performer this month',
                    style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(top.employeeName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${top.won} won  ·  ${top.leadsTaken} leads  ·  '
                  '${top.callsMade} calls',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${top.score}',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: scheme.primary),
              ),
              Text('points', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}
