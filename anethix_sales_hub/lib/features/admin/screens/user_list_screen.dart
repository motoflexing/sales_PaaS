import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/search_bar.dart';
import '../providers/user_management_provider.dart';
import '../widgets/user_card.dart';

class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: UserListTab.values.length,
    vsync: this,
  )..addListener(() {
      if (_tabController.indexIsChanging) return;
      ref.read(userListTabProvider.notifier).state =
          UserListTab.values[_tabController.index];
    });

  bool _isSearching = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(filteredUsersProvider);
    final query = ref.watch(userListQueryProvider);
    final tab = ref.watch(userListTabProvider);
    final allUsers = ref.watch(userManagementProvider).valueOrNull ?? const [];
    final managerNames = {
      for (final u in allUsers) u.id: u.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? AppSearchField(
                autofocus: true,
                hintText: 'Search name or email',
                initialValue: query,
                onChanged: (value) =>
                    ref.read(userListQueryProvider.notifier).state = value,
              )
            : const Text('Users'),
        titleSpacing: _isSearching ? 8 : null,
        centerTitle: !_isSearching,
        actions: [
          IconButton(
            icon:
                Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _isSearching ? 'Close search' : 'Search',
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (!_isSearching) {
                ref.read(userListQueryProvider.notifier).state = '';
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            for (final t in UserListTab.values) Tab(text: t.label),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.adminCreateUser),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add user'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(userManagementProvider.notifier).refresh(),
        child: usersAsync.when(
          loading: () => const LoadingState(itemHeight: 110),
          error: (error, _) => ScrollableEmptyState(
            child: ErrorState(
              message: ErrorState.describe(error),
              onRetry: () =>
                  ref.read(userManagementProvider.notifier).refresh(),
            ),
          ),
          data: (users) {
            if (users.isEmpty) {
              return ScrollableEmptyState(
                child: EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: query.isNotEmpty
                      ? 'No users match "$query"'
                      : 'No ${tab.label.toLowerCase()} yet',
                  message: tab == UserListTab.inactive
                      ? 'Deactivated accounts will appear here.'
                      : 'Create an account to get someone onto the team.',
                  actionLabel:
                      tab == UserListTab.inactive ? null : 'Add a user',
                  onAction: () => context.push(Routes.adminCreateUser),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                96,
              ),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => UserCard(
                user: users[index],
                managerName: managerNames[users[index].managerId],
                onTap: () => context.push(Routes.adminUser(users[index].id)),
              ),
            );
          },
        ),
      ),
    );
  }
}
