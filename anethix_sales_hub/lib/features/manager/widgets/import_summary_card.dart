import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/import_summary.dart';

/// Counts for a parsed file (before import) or an applied import (after).
class ImportSummaryCard extends StatelessWidget {
  const ImportSummaryCard({
    super.key,
    required this.total,
    required this.valid,
    required this.duplicate,
    required this.invalid,
    this.title = 'Import summary',
    this.validLabel = 'Ready',
  });

  ImportSummaryCard.fromSummary(
    ImportSummary summary, {
    super.key,
    this.title = 'Import complete',
    this.validLabel = 'Imported',
  })  : total = summary.total,
        valid = summary.imported,
        duplicate = summary.duplicate,
        invalid = summary.invalid;

  final int total;
  final int valid;
  final int duplicate;
  final int invalid;
  final String title;
  final String validLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 14),
          Row(
            children: [
              _Count(label: 'Total', value: total),
              _Count(
                label: validLabel,
                value: valid,
                color: Colors.green.shade700,
              ),
              _Count(
                label: 'Duplicate',
                value: duplicate,
                color: Colors.amber.shade800,
              ),
              _Count(label: 'Invalid', value: invalid, color: scheme.error),
              _Count(
                label: 'Skipped',
                value: duplicate + invalid,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          const SizedBox(height: 2),
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
