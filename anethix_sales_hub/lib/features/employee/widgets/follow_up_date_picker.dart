import 'package:flutter/material.dart';

import '../../../core/utils/date_utils.dart';

/// Picks a future date and time in two steps. Returns null if the user backs
/// out of either step.
Future<DateTime?> pickFollowUpDateTime(
  BuildContext context, {
  DateTime? initial,
  String helpText = 'Schedule follow-up',
}) async {
  final now = DateTime.now();
  final seed = initial != null && initial.isAfter(now)
      ? initial
      : now.add(const Duration(days: 1));

  final date = await showDatePicker(
    context: context,
    initialDate: seed,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365)),
    helpText: helpText,
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: seed.hour, minute: 0),
    helpText: 'Pick a time',
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Inline field that shows the chosen slot and opens the picker on tap.
class FollowUpDateField extends StatelessWidget {
  const FollowUpDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Schedule a follow-up',
    this.optional = true,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String label;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked =
            await pickFollowUpDateTime(context, initial: value);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_rounded),
          suffixIcon: value != null && optional
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Clear',
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(
          value == null
              ? (optional ? 'Not scheduled' : 'Tap to choose')
              : AppDate.relativeSlot(value!),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: value == null ? scheme.onSurfaceVariant : null,
          ),
        ),
      ),
    );
  }
}
