import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Medal for the podium, plain numeral for everyone else.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank, this.size = 36});

  final int rank;
  final double size;

  static const Map<int, String> _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

  Color _color(ColorScheme scheme) => switch (rank) {
        1 => AppColors.gold,
        2 => AppColors.silver,
        3 => AppColors.bronze,
        _ => scheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(theme.colorScheme);
    final medal = _medals[rank];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: medal != null ? 0.16 : 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: medal != null
          ? Text(medal, style: TextStyle(fontSize: size * 0.5))
          : Text(
              '$rank',
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
    );
  }
}
