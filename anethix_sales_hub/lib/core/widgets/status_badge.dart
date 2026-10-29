import 'package:flutter/material.dart';

import '../../shared/models/enums.dart';
import '../constants/lead_status.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.showIcon = true,
    this.compact = false,
  });

  final LeadStatus status;
  final bool showIcon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(status.icon, size: compact ? 11 : 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            status.label,
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

class FollowUpStatusBadge extends StatelessWidget {
  const FollowUpStatusBadge({super.key, required this.status});

  final FollowUpStatus status;

  Color _color(ColorScheme scheme) => switch (status) {
        FollowUpStatus.pending => scheme.primary,
        FollowUpStatus.completed => Colors.green.shade700,
        FollowUpStatus.rescheduled => Colors.amber.shade800,
        FollowUpStatus.overdue => scheme.error,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(theme.colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, this.isActive = true});

  final UserRole role;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? switch (role) {
            UserRole.admin => Colors.deepPurple.shade600,
            UserRole.manager => Colors.indigo.shade500,
            UserRole.employee => Colors.teal.shade600,
          }
        : theme.colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        role.label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Horizontal pipeline stepper. Stages up to and including [status] are
/// filled; anything ahead is greyed out. A lost lead paints the whole track in
/// the error colour since it left the pipeline.
class PipelineStepper extends StatelessWidget {
  const PipelineStepper({super.key, required this.status});

  final LeadStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLost = status == LeadStatus.lost;
    final currentIndex = pipelineStages.indexOf(status);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < pipelineStages.length; i++) ...[
            if (i > 0)
              Container(
                width: 18,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: (!isLost && i <= currentIndex)
                    ? scheme.primary
                    : scheme.outlineVariant,
              ),
            _Stage(
              stage: pipelineStages[i],
              isDone: !isLost && i < currentIndex,
              isCurrent: !isLost && i == currentIndex,
            ),
          ],
          if (isLost) ...[
            Container(
              width: 18,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: scheme.error,
            ),
            _Stage(
              stage: LeadStatus.lost,
              isDone: false,
              isCurrent: true,
              overrideColor: scheme.error,
            ),
          ],
        ],
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.stage,
    required this.isDone,
    required this.isCurrent,
    this.overrideColor,
  });

  final LeadStatus stage;
  final bool isDone;
  final bool isCurrent;
  final Color? overrideColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = isDone || isCurrent;
    final color = overrideColor ??
        (active ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.5));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCurrent ? 30 : 24,
          height: isCurrent ? 30 : 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color.withValues(alpha: 0.16) : Colors.transparent,
            border: Border.all(
              color: active ? color : scheme.outlineVariant,
              width: isCurrent ? 2 : 1.2,
            ),
          ),
          child: Icon(
            isDone ? Icons.check_rounded : stage.icon,
            size: isCurrent ? 16 : 13,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 56,
          child: Text(
            stage.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
