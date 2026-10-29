import 'package:flutter/material.dart';

import '../../shared/models/enums.dart';
import '../constants/lead_priority.dart';

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({
    super.key,
    required this.priority,
    this.compact = false,
  });

  final LeadPriority priority;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = priority.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(priority.icon, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 3),
          Text(
            priority.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Segmented control for choosing a priority (manager-side forms).
class PrioritySelector extends StatelessWidget {
  const PrioritySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final LeadPriority value;
  final ValueChanged<LeadPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<LeadPriority>(
      segments: [
        for (final p in LeadPriority.values)
          ButtonSegment<LeadPriority>(
            value: p,
            label: Text(p.label),
            icon: Icon(p.icon, color: value == p ? null : p.color),
          ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
