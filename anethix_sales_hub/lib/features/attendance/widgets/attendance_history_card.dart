import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/attendance_model.dart';
import '../../../shared/models/enums.dart';

/// One day of attendance: date, in/out times, hours and a status pill.
class AttendanceHistoryRow extends StatelessWidget {
  const AttendanceHistoryRow({
    super.key,
    required this.record,
    this.leadingName,
  });

  final AttendanceModel record;

  /// Set on the admin view, where rows are per employee rather than per day.
  final String? leadingName;

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
                  leadingName ?? AppDate.weekday(record.date),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  leadingName == null
                      ? AppDate.day(record.date)
                      : AppDate.weekday(record.date),
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
              AppDate.time(record.checkIn),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              record.checkOut == null ? '-' : AppDate.time(record.checkOut),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              record.checkOut == null
                  ? 'Open'
                  : AppDate.hours(record.workingHours),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          AttendanceStatusPill(
            status: record.status,
            isLate: record.isLate,
          ),
        ],
      ),
    );
  }
}

class AttendanceStatusPill extends StatelessWidget {
  const AttendanceStatusPill({
    super.key,
    required this.status,
    this.isLate = false,
  });

  final AttendanceStatus status;
  final bool isLate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      AttendanceStatus.present when isLate => ('Late', AppColors.warning),
      AttendanceStatus.present => ('Present', AppColors.success),
      AttendanceStatus.halfDay => ('Half-day', AppColors.warning),
      AttendanceStatus.absent => ('Absent', theme.colorScheme.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Column captions for the history table.
class AttendanceHistoryHeader extends StatelessWidget {
  const AttendanceHistoryHeader({super.key, this.firstColumn = 'Date'});

  final String firstColumn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(firstColumn, style: style)),
          Expanded(
            flex: 2,
            child: Text('In', textAlign: TextAlign.center, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text('Out', textAlign: TextAlign.center, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text('Hours', textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: 66),
        ],
      ),
    );
  }
}

/// Wraps history rows in a card with a header and dividers.
class AttendanceHistoryCard extends StatelessWidget {
  const AttendanceHistoryCard({
    super.key,
    required this.records,
    this.firstColumn = 'Date',
    this.nameResolver,
  });

  final List<AttendanceModel> records;
  final String firstColumn;
  final String Function(String employeeId)? nameResolver;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          AttendanceHistoryHeader(firstColumn: firstColumn),
          const Divider(height: 12),
          for (var i = 0; i < records.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            AttendanceHistoryRow(
              record: records[i],
              leadingName: nameResolver?.call(records[i].employeeId),
            ),
          ],
        ],
      ),
    );
  }
}
