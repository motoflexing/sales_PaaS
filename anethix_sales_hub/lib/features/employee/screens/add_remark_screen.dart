import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/lead_status.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../shared/models/enums.dart';
import '../providers/calling_provider.dart';
import '../providers/my_leads_provider.dart';
import '../widgets/follow_up_date_picker.dart';

/// Bottom sheet for adding a free-text remark to a lead.
class AddRemarkSheet extends ConsumerStatefulWidget {
  const AddRemarkSheet({
    super.key,
    required this.leadId,
    required this.leadName,
  });

  final String leadId;
  final String leadName;

  static Future<bool> show(
    BuildContext context, {
    required String leadId,
    required String leadName,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddRemarkSheet(leadId: leadId, leadName: leadName),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<AddRemarkSheet> createState() => _AddRemarkSheetState();
}

class _AddRemarkSheetState extends ConsumerState<AddRemarkSheet> {
  final _controller = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Opening the sheet means the existing remarks have been seen. Done here so
    // every entry point into it — the card, the workspace, the manager's lead
    // detail — clears the badge without repeating itself.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(remarkViewsProvider.notifier).markViewed(widget.leadId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Write a remark before saving');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(leadActionsProvider).addRemark(widget.leadId, text);
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add remark', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                widget.leadName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'What should the team know about this lead?',
                  errorText: _error,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const InlineSpinner()
                    : const Text('Save remark'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for moving a lead to its next pipeline stage.
class StatusUpdateSheet extends ConsumerStatefulWidget {
  const StatusUpdateSheet({
    super.key,
    required this.leadId,
    required this.current,
    required this.allowed,
  });

  final String leadId;
  final LeadStatus current;
  final List<LeadStatus> allowed;

  static Future<bool> show(
    BuildContext context, {
    required String leadId,
    required LeadStatus current,
    required List<LeadStatus> allowed,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          StatusUpdateSheet(leadId: leadId, current: current, allowed: allowed),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<StatusUpdateSheet> createState() => _StatusUpdateSheetState();
}

class _StatusUpdateSheetState extends ConsumerState<StatusUpdateSheet> {
  String? _busyStatus;

  Future<void> _apply(LeadStatus status) async {
    setState(() => _busyStatus = status.name);
    try {
      await ref.read(leadActionsProvider).updateStatus(widget.leadId, status);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _busyStatus = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Update status', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Currently ${widget.current.label}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (widget.allowed.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'This lead has reached the end of the pipeline.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.allowed.length,
                itemBuilder: (context, index) {
                  final status = widget.allowed[index];
                  final isBusy = _busyStatus == status.name;
                  return ListTile(
                    leading: Icon(status.icon, color: status.color),
                    title: Text(status.label),
                    trailing: isBusy
                        ? const InlineSpinner()
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: _busyStatus != null ? null : () => _apply(status),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Bottom sheet for scheduling a follow-up outside of the call flow.
class ScheduleFollowUpSheet extends ConsumerStatefulWidget {
  const ScheduleFollowUpSheet({
    super.key,
    required this.leadId,
    required this.leadName,
  });

  final String leadId;
  final String leadName;

  static Future<bool> show(
    BuildContext context, {
    required String leadId,
    required String leadName,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ScheduleFollowUpSheet(leadId: leadId, leadName: leadName),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<ScheduleFollowUpSheet> createState() =>
      _ScheduleFollowUpSheetState();
}

class _ScheduleFollowUpSheetState extends ConsumerState<ScheduleFollowUpSheet> {
  final _remarkController = TextEditingController();
  late DateTime? _scheduledAt = _defaultSlot();
  bool _isSaving = false;
  String? _error;

  static DateTime _defaultSlot() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 11);
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_scheduledAt == null) {
      setState(() => _error = 'Pick a date and time');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref
          .read(leadActionsProvider)
          .scheduleFollowUp(
            leadId: widget.leadId,
            scheduledAt: _scheduledAt!,
            remark: _remarkController.text,
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Schedule follow-up', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                widget.leadName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FollowUpDateField(
                value: _scheduledAt,
                optional: false,
                label: 'Date and time',
                onChanged: (value) => setState(() => _scheduledAt = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _remarkController,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'What do you need to cover?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const InlineSpinner()
                    : const Text('Schedule'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
