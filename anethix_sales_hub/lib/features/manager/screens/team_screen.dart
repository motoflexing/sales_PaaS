import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../providers/team_provider.dart';
import '../widgets/team_member_card.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'Leaderboard',
            onPressed: () => context.go(Routes.managerLeaderboard),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(teamProvider);
          await ref.read(teamProvider.future);
        },
        child: teamAsync.when(
          loading: () => const LoadingState(itemHeight: 150),
          error: (error, _) => ScrollableEmptyState(
            child: ErrorState(
              message: ErrorState.describe(error),
              onRetry: () => ref.invalidate(teamProvider),
            ),
          ),
          data: (members) {
            if (members.isEmpty) {
              return const ScrollableEmptyState(
                child: EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No one on your team yet',
                  message:
                      'Ask your admin to assign employees to you and they '
                      'will show up here.',
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                AppConstants.pagePadding,
                24,
              ),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => TeamMemberCard(
                summary: members[index],
                onTap: () => context.push(
                  Routes.managerEmployee(members[index].user.id),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
