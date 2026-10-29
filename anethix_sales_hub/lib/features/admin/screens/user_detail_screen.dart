import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/shared_providers.dart';
import '../../../shared/widgets/lead_sections.dart';
import '../providers/user_management_provider.dart';

class UserDetailScreen extends ConsumerStatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  bool _isBusy = false;

  Future<void> _toggleActive(UserModel user) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: user.isActive ? 'Deactivate ${user.firstName}?' : 'Reactivate?',
      message: user.isActive
          ? 'They will be signed out and blocked from signing in again. '
              'Their leads and history stay intact.'
          : '${user.name} will be able to sign in again.',
      confirmLabel: user.isActive ? 'Deactivate' : 'Reactivate',
      isDestructive: user.isActive,
      icon: user.isActive
          ? Icons.person_off_outlined
          : Icons.person_add_alt_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await ref
          .read(userManagementProvider.notifier)
          .setActive(user.id, !user.isActive);
      if (mounted) {
        context.showInfo(
          user.isActive ? 'Account deactivated.' : 'Account reactivated.',
        );
      }
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _changeManager(UserModel user) async {
    final managers = await ref.read(activeManagersProvider.future);
    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Assign to manager',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            for (final manager in managers)
              ListTile(
                leading: InitialsAvatar(name: manager.name, radius: 18),
                title: Text(manager.name),
                subtitle: Text(manager.email),
                trailing: manager.id == user.managerId
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(manager.id),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (selected == null || selected == user.managerId || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await ref
          .read(userManagementProvider.notifier)
          .assignManager(user.id, selected);
      if (mounted) context.showInfo('Manager updated.');
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _edit(UserModel user) async {
    final name = await PromptDialog.show(
      context,
      title: 'Edit name',
      hintText: 'Full name',
      confirmLabel: 'Save',
      isRequired: true,
      initialValue: user.name,
    );
    if (name == null || name == user.name || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await ref
          .read(userManagementProvider.notifier)
          .updateUser(userId: user.id, name: name);
      if (mounted) context.showInfo('Profile updated.');
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(userDetailProvider(widget.userId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User'),
        actions: [
          detailAsync.maybeWhen(
            data: (detail) => IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: _isBusy ? null : () => _edit(detail.user),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const LoadingState(itemHeight: 130),
        error: (error, _) => ErrorState(
          message: ErrorState.describe(error),
          onRetry: () => ref.invalidate(userDetailProvider(widget.userId)),
        ),
        data: (detail) {
          final user = detail.user;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              AppConstants.pagePadding,
              AppConstants.pagePadding,
              32,
            ),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        InitialsAvatar(name: user.name, radius: 26),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  RoleBadge(
                                    role: user.role,
                                    isActive: user.isActive,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    user.isActive ? 'Active' : 'Inactive',
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color: user.isActive
                                          ? AppColors.success
                                          : theme.colorScheme.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    DetailRow(
                      icon: Icons.alternate_email_rounded,
                      label: 'Email',
                      value: user.email,
                    ),
                    DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: user.phone,
                    ),
                    DetailRow(
                      icon: Icons.event_outlined,
                      label: 'Joined',
                      value: AppDate.day(user.joinDate),
                    ),
                    if (user.role == UserRole.employee)
                      DetailRow(
                        icon: Icons.supervisor_account_outlined,
                        label: 'Reports to',
                        value: detail.manager?.name ?? 'Unassigned',
                        onTap: _isBusy ? null : () => _changeManager(user),
                        trailing: Icon(
                          Icons.swap_horiz_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : () => _toggleActive(user),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      user.isActive ? theme.colorScheme.error : null,
                ),
                icon: _isBusy
                    ? const InlineSpinner(size: 16)
                    : Icon(
                        user.isActive
                            ? Icons.person_off_outlined
                            : Icons.person_add_alt_rounded,
                      ),
                label: Text(
                  user.isActive ? 'Deactivate account' : 'Reactivate account',
                ),
              ),
              if (user.role == UserRole.employee) ...[
                const SectionHeader(title: 'Performance'),
                StatGrid(
                  crossAxisCount: 4,
                  childAspectRatio: 0.95,
                  tiles: [
                    StatTile(
                      label: 'Attendance',
                      value: '${detail.attendanceDays}',
                    ),
                    StatTile(
                      label: 'Leads',
                      value: '${detail.leads.length}',
                    ),
                    StatTile(label: 'Calls', value: '${detail.calls}'),
                    StatTile(
                      label: 'Follow-ups',
                      value: '${detail.followUps}',
                    ),
                    StatTile(label: 'Meetings', value: '${detail.meetings}'),
                    StatTile(
                      label: 'Won',
                      value: '${detail.conversions}',
                      accent: AppColors.success,
                    ),
                    StatTile(
                      label: 'Score',
                      value: '${detail.score}',
                      accent: theme.colorScheme.primary,
                    ),
                    StatTile(
                      label: 'Open leads',
                      value: '${detail.leads.countWhere((l) => l.status != LeadStatus.won && l.status != LeadStatus.lost)}',
                    ),
                  ],
                ),
              ],
              const SectionHeader(title: 'Recent activity'),
              _UserActivity(userId: user.id),
            ],
          );
        },
      ),
    );
  }
}

class _UserActivity extends ConsumerWidget {
  const _UserActivity({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(_userActivityProvider(userId));

    return activityAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: InlineSpinner()),
      ),
      error: (error, _) => ErrorState(
        message: ErrorState.describe(error),
        onRetry: () => ref.invalidate(_userActivityProvider(userId)),
      ),
      data: (activities) => ActivityTimeline(
        activities: activities,
        showAuthor: false,
        emptyMessage: 'No recorded activity for this account.',
      ),
    );
  }
}

final _userActivityProvider =
    FutureProvider.autoDispose.family((ref, String userId) {
  ref.watch(dataRevisionProvider);
  return ref.read(activityRepositoryProvider).getForUser(userId, limit: 12);
});
