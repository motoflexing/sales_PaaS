import 'package:flutter/material.dart';

import '../../../core/constants/call_outcomes.dart';
import '../../../shared/models/enums.dart';

/// Radio list of every call outcome, coloured to match the outcome semantics.
class CallOutcomeSelector extends StatelessWidget {
  const CallOutcomeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CallOutcome? value;
  final ValueChanged<CallOutcome> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RadioGroup<CallOutcome>(
      groupValue: value,
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final outcome in CallOutcome.values)
            RadioListTile<CallOutcome>(
              value: outcome,
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Row(
                children: [
                  Icon(outcome.icon, size: 18, color: outcome.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      outcome.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: value == outcome
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact read-only chip used in call history rows.
class CallOutcomeChip extends StatelessWidget {
  const CallOutcomeChip({super.key, required this.outcome});

  final CallOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: outcome.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: outcome.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(outcome.icon, size: 12, color: outcome.color),
          const SizedBox(width: 4),
          Text(
            outcome.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: outcome.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
