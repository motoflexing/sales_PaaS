import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../providers/attendance_provider.dart';
import '../widgets/attendance_history_card.dart';
import '../widgets/check_in_button.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _isBusy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _isBusy = true);
    try {
      await action();
      if (mounted) context.showInfo(success);
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(attendanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: stateAsync.when(
        loading: () => const LoadingState(itemHeight: 110),
        error: (error, _) => ErrorState(
          message: ErrorState.describe(error),
          onRetry: () => ref.read(attendanceProvider.notifier).refresh(),
        ),
        data: (state) => RefreshIndicator(
          onRefresh: () => ref.read(attendanceProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              AppConstants.pagePadding,
              AppConstants.pagePadding,
              32,
            ),
            children: [
              CheckInCard(
                record: state.today,
                isBusy: _isBusy,
                onCheckIn: () => _run(
                  ref.read(attendanceProvider.notifier).checkIn,
                  'Checked in. Have a good day.',
                ),
                onCheckOut: () => _run(
                  ref.read(attendanceProvider.notifier).checkOut,
                  'Checked out. See you tomorrow.',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Days present',
                      value: '${state.presentDays}',
                      icon: Icons.event_available_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'Avg hours / day',
                      value: state.averageHours.toStringAsFixed(1),
                      icon: Icons.timelapse_rounded,
                    ),
                  ),
                ],
              ),
              const SectionHeader(title: 'Last 30 days'),
              if (state.history.isEmpty)
                const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No attendance history yet',
                  message: 'Your check-ins will appear here once you start.',
                )
              else
                AttendanceHistoryCard(records: state.history),
            ],
          ),
        ),
      ),
    );
  }
}
