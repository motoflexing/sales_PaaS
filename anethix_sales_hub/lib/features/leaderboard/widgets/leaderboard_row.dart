import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/leaderboard_entry.dart';
import 'rank_badge.dart';

/// One competitor's row. Card layout rather than a table so it stays readable
/// on a phone without horizontal scrolling.
class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({
    super.key,
    required this.entry,
    this.isCurrentUser = false,
    this.onTap,
  });

  final LeaderboardEntry entry;
  final bool isCurrentUser;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      onTap: onTap,
      color: isCurrentUser
          ? scheme.primaryContainer.withValues(alpha: 0.45)
          : null,
      borderColor:
          isCurrentUser ? scheme.primary.withValues(alpha: 0.4) : null,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              RankBadge(rank: entry.rank),
              const SizedBox(width: 12),
              InitialsAvatar(name: entry.employeeName, radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.employeeName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isCurrentUser)
                      Text(
                        'That is you',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.score}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.primary,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                  Text(
                    'points',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              _Metric(label: 'Leads', value: entry.leadsTaken),
              _Metric(label: 'Calls', value: entry.callsMade),
              _Metric(label: 'Follow-ups', value: entry.followUpsCompleted),
              _Metric(label: 'Meetings', value: entry.meetings),
              _Metric(label: 'Won', value: entry.won),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
