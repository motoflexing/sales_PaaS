import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/lead_model.dart';
import '../../../shared/models/enums.dart';
import '../providers/calling_provider.dart';
import '../widgets/call_outcome_selector.dart';
import '../widgets/follow_up_date_picker.dart';

/// Bottom sheet for recording what happened on a call. Returns true when a
/// call was saved so the caller can show a confirmation.
class CallLogSheet extends ConsumerStatefulWidget {
  const CallLogSheet({super.key, required this.lead});

  final LeadModel lead;

  static Future<bool> show(BuildContext context, LeadModel lead) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CallLogSheet(lead: lead),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<CallLogSheet> createState() => _CallLogSheetState();
}

class _CallLogSheetState extends ConsumerState<CallLogSheet> {
  final _remarkController = TextEditingController();

  CallOutcome? _outcome;
  DateTime? _followUpAt;
  bool _isSaving = false;
  String? _outcomeError;

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  /// Outcomes that imply another attempt; pre-fill a slot for those.
  void _onOutcomeChanged(CallOutcome outcome) {
    setState(() {
      _outcome = outcome;
      _outcomeError = null;
      final needsFollowUp = outcome == CallOutcome.followUpRequired ||
          outcome == CallOutcome.callBackLater;
      if (needsFollowUp && _followUpAt == null) {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        _followUpAt =
            DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 11);
      }
    });
  }

  Future<void> _save() async {
    if (_outcome == null) {
      setState(() => _outcomeError = 'Choose what happened on the call');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(leadActionsProvider).logCall(
            leadId: widget.lead.id,
            outcome: _outcome!,
            remark: _remarkController.text,
            followUpDate: _followUpAt,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log call', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.lead.name}  ·  ${widget.lead.phone}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text('Call outcome', style: theme.textTheme.titleSmall),
                  if (_outcomeError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _outcomeError!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 4),
                  CallOutcomeSelector(
                    value: _outcome,
                    onChanged: _onOutcomeChanged,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _remarkController,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Call remark',
                      hintText: 'What did the prospect say?',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FollowUpDateField(
                    value: _followUpAt,
                    onChanged: (value) => setState(() => _followUpAt = value),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const InlineSpinner()
                        : const Text('Save call log'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
