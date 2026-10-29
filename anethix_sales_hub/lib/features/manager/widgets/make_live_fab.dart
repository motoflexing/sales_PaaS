import 'package:flutter/material.dart';

import '../../../core/widgets/loading_state.dart';

/// Speed-dial FAB for adding a lead manually or importing a sheet.
class LeadSpeedDial extends StatefulWidget {
  const LeadSpeedDial({
    super.key,
    required this.onAddLead,
    required this.onImportLeads,
  });

  final VoidCallback onAddLead;
  final VoidCallback onImportLeads;

  @override
  State<LeadSpeedDial> createState() => _LeadSpeedDialState();
}

class _LeadSpeedDialState extends State<LeadSpeedDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  bool _isOpen = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    _isOpen ? _controller.forward() : _controller.reverse();
  }

  void _run(VoidCallback action) {
    _toggle();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizeTransition(
          sizeFactor: _controller,
          alignment: Alignment.bottomCenter,
          child: FadeTransition(
            opacity: _controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MiniAction(
                  label: 'Import Leads',
                  icon: Icons.upload_file_rounded,
                  onPressed: () => _run(widget.onImportLeads),
                ),
                const SizedBox(height: 10),
                _MiniAction(
                  label: 'Add Lead',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: () => _run(widget.onAddLead),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        FloatingActionButton(
          onPressed: _toggle,
          tooltip: _isOpen ? 'Close' : 'Add leads',
          child: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: label,
      onPressed: onPressed,
      elevation: 2,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// Bottom bar shown while drafts are selected on the manager leads screen.
class MakeLiveBar extends StatelessWidget {
  const MakeLiveBar({
    super.key,
    required this.selectedCount,
    required this.onMakeLive,
    required this.onClear,
    this.onAssign,
    this.isBusy = false,
  });

  final int selectedCount;
  final VoidCallback onMakeLive;
  final VoidCallback onClear;

  /// Direct assignment to one employee. Omitted, the bar keeps its original
  /// make-live-only shape.
  final VoidCallback? onAssign;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Clear selection',
                    onPressed: isBusy ? null : onClear,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$selectedCount selected',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  // With no assign action the make-live button keeps its
                  // original place on the count row.
                  if (onAssign == null)
                    FilledButton.icon(
                      onPressed: isBusy ? null : onMakeLive,
                      icon: isBusy
                          ? InlineSpinner(size: 15, color: scheme.onPrimary)
                          : const Icon(Icons.podcasts_rounded, size: 18),
                      label: const Text('MAKE LIVE'),
                    ),
                ],
              ),
              if (onAssign != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isBusy ? null : onAssign,
                        icon: const Icon(Icons.person_add_alt_1_rounded,
                            size: 18),
                        label: const Text(
                          'ASSIGN TO EMPLOYEE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isBusy ? null : onMakeLive,
                        icon: isBusy
                            ? InlineSpinner(size: 15, color: scheme.onPrimary)
                            : const Icon(Icons.podcasts_rounded, size: 18),
                        label: const Text(
                          'MAKE LIVE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
