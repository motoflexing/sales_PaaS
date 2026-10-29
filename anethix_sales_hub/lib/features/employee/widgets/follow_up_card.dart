import 'package:flutter/material.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../shared/models/enums.dart';
import '../providers/employee_follow_up_provider.dart';

class FollowUpCard extends StatelessWidget {
  const FollowUpCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onCall,
    this.onComplete,
    this.onReschedule,
    this.onRemark,
    this.showActions = true,
    this.ownerName,
  });

  final FollowUpWithLead entry;
  final VoidCallback? onTap;
  final VoidCallback? onCall;
  final VoidCallback? onComplete;
  final VoidCallback? onReschedule;
  final VoidCallback? onRemark;
  final bool showActions;

  /// Shown on the manager view where follow-ups span the whole team.
  final String? ownerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final followUp = entry.followUp;
    final lead = entry.lead;
    final isOverdue = entry.isOverdue &&
        followUp.status != FollowUpStatus.completed;
    final isDone = followUp.status == FollowUpStatus.completed;

    return AppCard(
      onTap: onTap,
      borderColor: isOverdue ? scheme.error.withValues(alpha: 0.4) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead?.name ?? 'Lead removed',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lead?.company != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        lead!.company!,
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
              FollowUpStatusBadge(
                status: isOverdue ? FollowUpStatus.overdue : followUp.status,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle_rounded : Icons.schedule_rounded,
                size: 15,
                color: isOverdue
                    ? scheme.error
                    : isDone
                        ? Colors.green.shade600
                        : scheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isDone
                      ? 'Completed ${AppDate.ago(followUp.completedAt)}'
                      : isOverdue
                          ? AppDate.overdueBy(followUp.scheduledAt)
                          : AppDate.relativeSlot(followUp.scheduledAt),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isOverdue ? scheme.error : scheme.onSurfaceVariant,
                    fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (ownerName != null)
                Text(
                  ownerName!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (followUp.remark != null) ...[
            const SizedBox(height: 8),
            Text(
              followUp.remark!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (showActions && !isDone) ...[
            const Divider(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (onCall != null)
                  _Action(
                    icon: Icons.phone_rounded,
                    label: 'Call',
                    onTap: onCall!,
                  ),
                if (onComplete != null)
                  _Action(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Complete',
                    color: Colors.green.shade600,
                    onTap: onComplete!,
                  ),
                if (onReschedule != null)
                  _Action(
                    icon: Icons.update_rounded,
                    label: 'Reschedule',
                    onTap: onReschedule!,
                  ),
                if (onRemark != null)
                  _Action(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Remark',
                    onTap: onRemark!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: color ?? theme.colorScheme.primary),
            const SizedBox(height: 3),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
