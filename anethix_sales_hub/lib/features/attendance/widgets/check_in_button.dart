import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/attendance_model.dart';

/// Today's attendance card: check in, check out, or a read-only summary once
/// the day is closed. Ticks every minute while a session is open.
class CheckInCard extends StatefulWidget {
  const CheckInCard({
    super.key,
    required this.record,
    required this.onCheckIn,
    required this.onCheckOut,
    this.isBusy = false,
    this.compact = false,
  });

  final AttendanceModel? record;
  final Future<void> Function() onCheckIn;
  final Future<void> Function() onCheckOut;
  final bool isBusy;
  final bool compact;

  @override
  State<CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends State<CheckInCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant CheckInCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    final isOpen = widget.record != null && widget.record!.checkOut == null;
    if (isOpen && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    } else if (!isOpen) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final record = widget.record;

    if (record == null) {
      return AppCard(
        child: Row(
          children: [
            _Badge(
              icon: Icons.login_rounded,
              color: AppColors.checkIn,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Not checked in', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    AppDate.time(DateTime.now()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: widget.isBusy ? null : widget.onCheckIn,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.checkIn,
                  foregroundColor: Colors.white,
                ),
                icon: widget.isBusy
                    ? const InlineSpinner(size: 14, color: Colors.white)
                    : const Icon(Icons.login_rounded, size: 18),
                label: const Text('CHECK IN'),
              ),
            ),
          ],
        ),
      );
    }

    if (record.checkOut != null) {
      return AppCard(
        child: Row(
          children: [
            _Badge(icon: Icons.task_alt_rounded, color: AppColors.success),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's shift is closed",
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '${AppDate.time(record.checkIn)} - '
                    '${AppDate.time(record.checkOut)}  ·  '
                    '${AppDate.hours(record.workingHours)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final elapsed = DateTime.now().difference(record.checkIn);
    return AppCard(
      borderColor: AppColors.checkOut.withValues(alpha: 0.35),
      child: Row(
        children: [
          _Badge(icon: Icons.timer_rounded, color: AppColors.checkOut),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Working  ·  ${AppDate.duration(elapsed)}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Checked in at ${AppDate.time(record.checkIn)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: widget.isBusy ? null : widget.onCheckOut,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.checkOut,
                foregroundColor: Colors.white,
              ),
              icon: widget.isBusy
                  ? const InlineSpinner(size: 14, color: Colors.white)
                  : const Icon(Icons.logout_rounded, size: 18),
              label: const Text('CHECK OUT'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }
}
