import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../shared/widgets/lead_sections.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../attendance/widgets/check_in_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/employee_dashboard_provider.dart';
import '../widgets/follow_up_card.dart';

class EmployeeHomeScreen extends ConsumerStatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  ConsumerState<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends ConsumerState<EmployeeHomeScreen> {
  bool _isAttendanceBusy = false;

  Future<void> _runAttendance(
    Future<void> Function() action,
    String success,
  ) async {
    setState(() => _isAttendanceBusy = true);
    try {
      await action();
      if (mounted) context.showInfo(success);
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _isAttendanceBusy = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to work your leads.',
      confirmLabel: 'Sign out',
      isDestructive: true,
      icon: Icons.logout_rounded,
    );
    if (confirmed) await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final dashboardAsync = ref.watch(employeeDashboardProvider);
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
            Text(
              user?.firstName ?? 'there',
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Attendance',
            onPressed: () => context.push(Routes.employeeAttendance),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: _logout,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: InitialsAvatar(name: user?.name ?? '?', radius: 18),
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const LoadingState(itemHeight: 120),
        error: (error, _) => ErrorState(
          message: ErrorState.describe(error),
          onRetry: () => ref.invalidate(employeeDashboardProvider),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(employeeDashboardProvider);
            await ref.read(employeeDashboardProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              AppConstants.pagePadding,
              AppConstants.pagePadding,
              32,
            ),
            children: [
              CheckInCard(
                record: data.attendance,
                isBusy: _isAttendanceBusy,
                onCheckIn: () => _runAttendance(
                  ref.read(attendanceProvider.notifier).checkIn,
                  'Checked in. Have a good day.',
                ),
                onCheckOut: () => _runAttendance(
                  ref.read(attendanceProvider.notifier).checkOut,
                  'Checked out. See you tomorrow.',
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: MiniStat(
                        label: 'My Leads',
                        value: '${data.myLeadCount}',
                      ),
                    ),
                    Expanded(
                      child: MiniStat(
                        label: 'Calls Today',
                        value: '${data.callsToday}',
                      ),
                    ),
                    Expanded(
                      child: MiniStat(
                        label: 'Due Today',
                        value: '${data.followUpsDue}',
                        accent: data.followUpsDue > 0
                            ? theme.colorScheme.primary
                            : null,
                      ),
                    ),
                    Expanded(
                      child: MiniStat(
                        label: data.rank > 0 ? 'Score (#${data.rank})' : 'Score',
                        value: '${data.score}',
                      ),
                    ),
                  ],
                ),
              ),
              if (data.overdueCount > 0) ...[
                const SizedBox(height: 12),
                _OverdueBanner(count: data.overdueCount),
              ],
              SectionHeader(
                title: "Today's follow-ups",
                actionLabel: data.todaysFollowUps.isEmpty ? null : 'See all',
                onAction: () => context.go(Routes.employeeFollowUps),
              ),
              if (data.todaysFollowUps.isEmpty)
                AppCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nothing scheduled for today. '
                          'Claim a live lead to fill your pipeline.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final entry in data.todaysFollowUps.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FollowUpCard(
                      entry: entry,
                      showActions: false,
                      onTap: entry.lead == null
                          ? null
                          : () =>
                              context.push(Routes.employeeLead(entry.lead!.id)),
                    ),
                  ),
              const SectionHeader(title: 'Recent activity'),
              ActivityTimeline(
                activities: data.recentActivity,
                showAuthor: false,
                emptyMessage: 'Your activity will show up here as you work.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverdueBanner extends StatelessWidget {
  const _OverdueBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      onTap: () => context.go(Routes.employeeFollowUps),
      color: scheme.errorContainer.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count follow-up${count == 1 ? ' is' : 's are'} overdue',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.error),
        ],
      ),
    );
  }
}
