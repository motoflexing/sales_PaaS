import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/import_summary.dart';
import '../../../data/repositories/lead_repository.dart';
import '../../../shared/providers/shared_providers.dart';
import '../../auth/providers/auth_provider.dart';

enum ImportStage { pickFile, parsing, preview, importing, done }

/// Sheet column to lead field mapping, shown for review before import.
const Map<String, String> defaultColumnMapping = {
  'Name': 'name',
  'Company': 'company',
  'Contact Person': 'contactPerson',
  'Phone': 'phone',
  'Email': 'email',
  'City': 'location',
  'Industry': 'industry',
  'Source': 'source',
  'Lead Type': 'leadType',
  'Priority': 'priority',
};

class LeadImportState {
  const LeadImportState({
    this.stage = ImportStage.pickFile,
    this.fileName,
    this.rows = const [],
    this.summary,
    this.error,
  });

  final ImportStage stage;
  final String? fileName;
  final List<ParsedLeadRow> rows;
  final ImportSummary? summary;
  final String? error;

  int get validCount => rows.where((r) => r.isImportable).length;
  int get duplicateCount => rows.where((r) => r.isDuplicate && r.isValid).length;
  int get invalidCount => rows.where((r) => !r.isValid).length;

  LeadImportState copyWith({
    ImportStage? stage,
    String? fileName,
    List<ParsedLeadRow>? rows,
    ImportSummary? summary,
    String? error,
    bool clearError = false,
  }) {
    return LeadImportState(
      stage: stage ?? this.stage,
      fileName: fileName ?? this.fileName,
      rows: rows ?? this.rows,
      summary: summary ?? this.summary,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LeadImportNotifier extends Notifier<LeadImportState> {
  @override
  LeadImportState build() => const LeadImportState();

  void reset() => state = const LeadImportState();

  /// Opens the system picker, then parses whatever comes back.
  Future<void> pickAndParse() async {
    state = state.copyWith(clearError: true);

    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx', 'xls'],
      );
    } catch (_) {
      state = state.copyWith(
        error: 'Could not open the file picker on this device.',
      );
      return;
    }

    if (file == null) return;
    await parseFile(file.name);
  }

  Future<void> parseFile(String fileName) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    state = LeadImportState(stage: ImportStage.parsing, fileName: fileName);
    try {
      final rows = await ref.read(leadRepositoryProvider).parseImportFile(
            fileName: fileName,
            managerId: user.id,
          );
      state = state.copyWith(stage: ImportStage.preview, rows: rows);
    } on LeadRepositoryException catch (error) {
      state = LeadImportState(
        stage: ImportStage.pickFile,
        fileName: fileName,
        error: error.message,
      );
    } catch (_) {
      state = LeadImportState(
        stage: ImportStage.pickFile,
        fileName: fileName,
        error: 'We could not read that file. Please check the format.',
      );
    }
  }

  Future<void> approve() async {
    final user = ref.read(authProvider);
    if (user == null || state.rows.isEmpty) return;

    state = state.copyWith(stage: ImportStage.importing, clearError: true);
    try {
      final summary = await ref
          .read(leadRepositoryProvider)
          .importLeads(state.rows, user.id);
      state = state.copyWith(stage: ImportStage.done, summary: summary);
      ref.bumpDataRevision();
    } catch (error) {
      state = state.copyWith(
        stage: ImportStage.preview,
        error: 'The import failed part-way through. Please try again.',
      );
    }
  }
}

final leadImportProvider =
    NotifierProvider<LeadImportNotifier, LeadImportState>(
  LeadImportNotifier.new,
);
