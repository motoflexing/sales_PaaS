import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_dashboard_provider.dart';
import '../widgets/admin_chart_section.dart';
import '../widgets/admin_stats_grid.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to administer the workspace.',
      confirmLabel: 'Sign out',
      isDestructive: true,
      icon: Icons.logout_rounded,
    );
    if (confirmed) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(adminDashboardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Overdue follow-ups',
            onPressed: () => context.go(Routes.adminReports),
            icon: Badge(
              isLabelVisible:
                  (dataAsync.valueOrNull?.overdueFollowUps ?? 0) > 0,
              label: Text('${dataAsync.valueOrNull?.overdueFollowUps ?? 0}'),
              backgroundColor: theme.colorScheme.error,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => _logout(context, ref),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const LoadingGridState(),
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
              HeadcountStrip(data: data),
              const SectionHeader(title: 'Leads'),
              AdminLeadStatsGrid(data: data),
              const SectionHeader(title: 'Activity'),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Calls today',
                      value: '${data.callsToday}',
                      icon: Icons.phone_in_talk_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'Follow-ups today',
                      value: '${data.followUpsToday}',
                      icon: Icons.event_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'Overdue',
                      value: '${data.overdueFollowUps}',
                      icon: Icons.warning_amber_rounded,
                      accent: data.overdueFollowUps > 0
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ),
                ],
              ),
              SectionHeader(
                title: 'Leaderboard',
                actionLabel: 'View all',
                onAction: () => context.push(Routes.adminLeaderboard),
              ),
              TopPerformerCard(data: data),
              const SectionHeader(title: 'Charts'),
              AdminChartSection(data: data),
            ],
          ),
        ),
      ),
    );
  }
}
