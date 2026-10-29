import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../providers/lead_import_provider.dart';
import '../widgets/import_preview_table.dart';
import '../widgets/import_summary_card.dart';

class ImportLeadsScreen extends ConsumerWidget {
  const ImportLeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leadImportProvider);
    final notifier = ref.read(leadImportProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import leads'),
        actions: [
          if (state.stage != ImportStage.pickFile)
            TextButton(
              onPressed: notifier.reset,
              child: const Text('Start over'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.pagePadding,
          AppConstants.pagePadding,
          AppConstants.pagePadding,
          32,
        ),
        children: [
          _StepIndicator(stage: state.stage),
          const SizedBox(height: 16),
          if (state.error != null) ...[
            _ErrorBanner(message: state.error!),
            const SizedBox(height: 16),
          ],
          switch (state.stage) {
            ImportStage.pickFile => _PickFileStep(
                onPick: notifier.pickAndParse,
                onUseSample: () => notifier.parseFile('sample_leads.csv'),
              ),
            ImportStage.parsing => _ParsingStep(fileName: state.fileName),
            ImportStage.preview => _PreviewStep(
                state: state,
                onApprove: () async {
                  await notifier.approve();
                  final summary = ref.read(leadImportProvider).summary;
                  if (context.mounted && summary != null) {
                    context.showInfo(
                      '${summary.imported} leads imported as drafts.',
                    );
                  }
                },
              ),
            ImportStage.importing => const _ImportingStep(),
            ImportStage.done => _DoneStep(state: state),
          },
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.stage});

  final ImportStage stage;

  static const List<(String, ImportStage)> _steps = [
    ('Pick file', ImportStage.pickFile),
    ('Review', ImportStage.preview),
    ('Import', ImportStage.done),
  ];

  int get _currentIndex => switch (stage) {
        ImportStage.pickFile => 0,
        ImportStage.parsing => 0,
        ImportStage.preview => 1,
        ImportStage.importing => 1,
        ImportStage.done => 2,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: i <= _currentIndex
                    ? scheme.primary
                    : scheme.outlineVariant,
              ),
            ),
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= _currentIndex
                      ? scheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: i <= _currentIndex
                        ? scheme.primary
                        : scheme.outlineVariant,
                  ),
                ),
                child: Icon(
                  i < _currentIndex ? Icons.check_rounded : Icons.circle,
                  size: i < _currentIndex ? 14 : 7,
                  color: i <= _currentIndex
                      ? scheme.onPrimary
                      : scheme.outlineVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _steps[i].$1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: i <= _currentIndex
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                  fontWeight:
                      i == _currentIndex ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PickFileStep extends StatelessWidget {
  const _PickFileStep({required this.onPick, required this.onUseSample});

  final VoidCallback onPick;
  final VoidCallback onUseSample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                ),
                child: Icon(
                  Icons.upload_file_rounded,
                  size: 34,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Upload a lead sheet',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Pick a .csv or .xlsx file. We will match the columns, flag '
                'duplicates and invalid rows, and show you a preview before '
                'anything is saved.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Choose file'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onUseSample,
                child: const Text('Use a sample file instead'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const ColumnMappingCard(mapping: defaultColumnMapping),
      ],
    );
  }
}

class _ParsingStep extends StatelessWidget {
  const _ParsingStep({this.fileName});

  final String? fileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text('Reading your file', style: theme.textTheme.titleSmall),
          if (fileName != null) ...[
            const SizedBox(height: 4),
            Text(
              fileName!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({required this.state, required this.onApprove});

  final LeadImportState state;
  final Future<void> Function() onApprove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.fileName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.fileName!,
                    style: theme.textTheme.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        const ColumnMappingCard(mapping: defaultColumnMapping),
        const SizedBox(height: 12),
        ImportSummaryCard(
          title: 'What we found',
          total: state.rows.length,
          valid: state.validCount,
          duplicate: state.duplicateCount,
          invalid: state.invalidCount,
        ),
        const SizedBox(height: 12),
        ImportPreviewTable(rows: state.rows),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: state.validCount == 0 ? null : onApprove,
          icon: const Icon(Icons.download_done_rounded),
          label: Text(
            state.validCount == 0
                ? 'Nothing to import'
                : 'Approve import (${state.validCount})',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Duplicate and invalid rows are skipped automatically.',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ImportingStep extends StatelessWidget {
  const _ImportingStep();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Importing leads',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.state});

  final LeadImportState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = state.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 56,
                color: AppColors.success,
              ),
              const SizedBox(height: 16),
              Text('Import complete', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'The imported leads are sitting in your Draft tab. '
                'Select them there and make them live.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (summary != null) ...[
          const SizedBox(height: 12),
          ImportSummaryCard.fromSummary(summary),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to leads'),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      color: scheme.errorContainer.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
