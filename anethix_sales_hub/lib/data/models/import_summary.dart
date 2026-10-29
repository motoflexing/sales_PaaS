import 'lead_model.dart';

class ImportSummary {
  const ImportSummary({
    required this.total,
    required this.imported,
    required this.duplicate,
    required this.invalid,
    required this.skipped,
  });

  final int total;
  final int imported;
  final int duplicate;
  final int invalid;
  final int skipped;

  static const ImportSummary empty = ImportSummary(
    total: 0,
    imported: 0,
    duplicate: 0,
    invalid: 0,
    skipped: 0,
  );
}

/// One parsed row from an uploaded sheet, plus why it was rejected (if it was).
class ParsedLeadRow {
  const ParsedLeadRow({
    required this.rowNumber,
    required this.lead,
    required this.isValid,
    required this.isDuplicate,
    this.issue,
  });

  final int rowNumber;
  final LeadModel lead;
  final bool isValid;
  final bool isDuplicate;
  final String? issue;

  bool get isImportable => isValid && !isDuplicate;
}
