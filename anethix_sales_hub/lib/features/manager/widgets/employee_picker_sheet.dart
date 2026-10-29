import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/search_bar.dart';
import '../providers/team_provider.dart';

/// Bottom sheet listing the manager's team so a lead can be handed to one of
/// them directly. Pops the chosen employee's id; the caller owns the confirm
/// step and the write, so the same sheet serves both the multi-select bar on
/// the leads screen and the single-lead detail screen.
class EmployeePickerSheet extends ConsumerStatefulWidget {
  const EmployeePickerSheet({super.key, required this.title});

  final String title;

  /// Shows the sheet and resolves to the selected employee id, or null if the
  /// manager dismissed it.
  static Future<String?> show(
    BuildContext context, {
    required int leadCount,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => EmployeePickerSheet(
        title: 'Assign $leadCount lead${leadCount == 1 ? '' : 's'} to employee',
      ),
    );
  }

  @override
  ConsumerState<EmployeePickerSheet> createState() =>
      _EmployeePickerSheetState();
}

class _EmployeePickerSheetState extends ConsumerState<EmployeePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teamAsync = ref.watch(teamProvider);

    return SafeArea(
      child: Padding(
        // Keeps the search field clear of the keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AppSearchField(
                  hintText: 'Search team members',
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: teamAsync.when(
                  loading: () => const LoadingState(itemHeight: 72),
                  error: (error, _) => ErrorState(
                    message: ErrorState.describe(error),
                    onRetry: () => ref.invalidate(teamProvider),
                  ),
                  data: (team) {
                    final members = _query.isEmpty
                        ? team
                        : team
                            .where((m) => m.user.name.containsIgnoreCase(_query))
                            .toList(growable: false);

                    if (members.isEmpty) {
                      return EmptyState(
                        icon: Icons.groups_outlined,
                        title: team.isEmpty
                            ? 'No team members yet'
                            : 'No one matches "$_query"',
                        message: team.isEmpty
                            ? 'Leads can only be assigned to employees who '
                                'report to you. Ask an admin to add someone to '
                                'your team.'
                            : 'Try a different name.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return ListTile(
                          leading:
                              InitialsAvatar(name: member.user.name, radius: 20),
                          title: Text(member.user.name),
                          subtitle: Text(
                            '${member.leadsTaken} lead'
                            '${member.leadsTaken == 1 ? '' : 's'}'
                            '  ·  ${member.score} pts',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () =>
                              Navigator.of(context).pop(member.user.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
