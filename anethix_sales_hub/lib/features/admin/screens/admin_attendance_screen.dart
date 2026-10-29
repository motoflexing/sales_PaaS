import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/models/enums.dart';
import '../../attendance/widgets/attendance_history_card.dart';
import '../providers/user_management_provider.dart';

class AdminAttendanceScreen extends ConsumerWidget {
  const AdminAttendanceScreen({super.key});

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final current = ref.read(adminAttendanceDateProvider);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Attendance for',
    );
    if (picked != null) {
      ref.read(adminAttendanceDateProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(adminAttendanceProvider);
    final date = ref.watch(adminAttendanceDateProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Pick a date',
            onPressed: () => _pickDate(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              12,
              AppConstants.pagePadding,
              4,
            ),
            child: AppCard(
              onTap: () => _pickDate(context, ref),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppDate.isToday(date)
                          ? 'Today, ${AppDate.day(date)}'
                          : AppDate.weekday(date),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded),
                ],
              ),
            ),
          ),
          Expanded(
            child: snapshotAsync.when(
              loading: () => const LoadingState(itemHeight: 90),
              error: (error, _) => ErrorState(
                message: ErrorState.describe(error),
                onRetry: () => ref.invalidate(adminAttendanceProvider),
              ),
              data: (snapshot) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(adminAttendanceProvider);
                  await ref.read(adminAttendanceProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.pagePadding,
                    8,
                    AppConstants.pagePadding,
                    32,
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: 'Present',
                            value: '${snapshot.present}',
                            icon: Icons.check_circle_outline_rounded,
                            accent: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            label: 'Absent',
                            value: '${snapshot.absent}',
                            icon: Icons.remove_circle_outline_rounded,
                            accent: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            label: 'Late',
                            value: '${snapshot.late}',
                            icon: Icons.schedule_rounded,
                            accent: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            label: 'Total',
                            value: '${snapshot.staff.length}',
                            icon: Icons.people_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SectionHeader(title: 'By employee'),
                    if (snapshot.staff.isEmpty)
                      const EmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'No active staff',
                        message: 'Add users to start tracking attendance.',
                      )
                    else
                      AppCard(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          children: [
                            const AttendanceHistoryHeader(
                              firstColumn: 'Employee',
                            ),
                            const Divider(height: 12),
                            for (var i = 0;
                                i < snapshot.staff.length;
                                i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _StaffRow(
                                user: snapshot.staff[i],
                                record:
                                    snapshot.records[snapshot.staff[i].id],
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.user, required this.record});

  final UserModel user;
  final AttendanceModel? record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user.role.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              record == null ? '-' : AppDate.time(record!.checkIn),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              record?.checkOut == null ? '-' : AppDate.time(record!.checkOut),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              record == null
                  ? '-'
                  : record!.checkOut == null
                      ? 'Open'
                      : AppDate.hours(record!.workingHours),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          AttendanceStatusPill(
            status: record?.status ?? AttendanceStatus.absent,
            isLate: record?.isLate ?? false,
          ),
        ],
      ),
    );
  }
}
