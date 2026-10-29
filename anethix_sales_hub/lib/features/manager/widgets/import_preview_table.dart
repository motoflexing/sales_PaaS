import 'package:flutter/material.dart';

import '../../../core/widgets/app_card.dart';
import '../../../data/models/import_summary.dart';

/// First rows of a parsed sheet, with rejected rows visibly flagged.
class ImportPreviewTable extends StatelessWidget {
  const ImportPreviewTable({
    super.key,
    required this.rows,
    this.maxRows = 10,
  });

  final List<ParsedLeadRow> rows;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = rows.take(maxRows).toList(growable: false);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Showing ${preview.length} of ${rows.length} rows',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 56,
              columnSpacing: 22,
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Company')),
                DataColumn(label: Text('Contact')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('City')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final row in preview)
                  DataRow(
                    color: row.isImportable
                        ? null
                        : WidgetStatePropertyAll(
                            scheme.errorContainer.withValues(alpha: 0.3),
                          ),
                    cells: [
                      DataCell(Text('${row.rowNumber}')),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: Text(
                            row.lead.company ?? '-',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 120,
                          child: Text(
                            row.lead.contactPerson ?? '-',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(row.lead.phone)),
                      DataCell(Text(row.lead.location ?? '-')),
                      DataCell(_RowStatus(row: row)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RowStatus extends StatelessWidget {
  const _RowStatus({required this.row});

  final ParsedLeadRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (label, color) = !row.isValid
        ? ('Invalid', scheme.error)
        : row.isDuplicate
            ? ('Duplicate', Colors.amber.shade800)
            : ('Ready', Colors.green.shade700);

    return Tooltip(
      message: row.issue ?? 'Will be imported as a draft',
      child: Container(
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
      ),
    );
  }
}

/// Read-only view of how sheet columns were matched to lead fields.
class ColumnMappingCard extends StatelessWidget {
  const ColumnMappingCard({super.key, required this.mapping});

  final Map<String, String> mapping;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Detected columns', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'These sheet columns were matched automatically.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in mapping.entries)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.key, style: theme.textTheme.labelMedium),
                      Icon(
                        Icons.arrow_right_alt_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      Text(
                        entry.value,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
