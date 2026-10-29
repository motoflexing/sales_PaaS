import 'package:flutter/material.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/lead_model.dart';

/// Manager/admin view of a lead, with optional multi-select for publishing.
class ManagerLeadCard extends StatelessWidget {
  const ManagerLeadCard({
    super.key,
    required this.lead,
    required this.onTap,
    this.assigneeName,
    this.isSelectable = false,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  final LeadModel lead;
  final VoidCallback onTap;
  final String? assigneeName;
  final bool isSelectable;
  final bool isSelected;
  final ValueChanged<bool>? onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      onTap: isSelectable ? () => onSelectedChanged?.call(!isSelected) : onTap,
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.4)
          : null,
      borderColor:
          isSelected ? scheme.primary.withValues(alpha: 0.45) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSelectable)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (value) =>
                          onSelectedChanged?.call(value ?? false),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lead.company != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        lead.company!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PriorityBadge(priority: lead.priority, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.phone_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(lead.phone, style: theme.textTheme.bodySmall),
              const Spacer(),
              StatusBadge(status: lead.status, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (assigneeName != null) ...[
                InitialsAvatar(name: assigneeName!, radius: 10),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    assigneeName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ] else
                Text(
                  lead.isAvailable ? 'Unclaimed' : 'No assignee',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              Icon(
                Icons.update_rounded,
                size: 13,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                AppDate.ago(lead.lastActivityAt ?? lead.updatedAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
