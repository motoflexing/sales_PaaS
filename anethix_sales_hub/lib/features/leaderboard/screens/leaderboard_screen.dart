import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/leaderboard_entry.dart';
import '../../../shared/models/enums.dart';
import '../providers/leaderboard_provider.dart';
import '../widgets/leaderboard_row.dart';
import '../widgets/period_filter_chips.dart';
import '../widgets/rank_badge.dart';

/// Shared across roles. Employees additionally get a pinned "Your rank" card.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key, this.showAppBarBack = false});

  final bool showAppBarBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(leaderboardPeriodProvider);
    final entriesAsync = ref.watch(leaderboardProvider);
    final myEntry = ref.watch(myLeaderboardEntryProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        automaticallyImplyLeading: showAppBarBack,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PeriodFilterChips(
              selected: period,
              onSelected: (value) =>
                  ref.read(leaderboardPeriodProvider.notifier).state = value,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (myEntry != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.pagePadding,
                12,
                AppConstants.pagePadding,
                0,
              ),
              child: _YourRankCard(entry: myEntry, period: period),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(leaderboardProvider);
                await ref.read(leaderboardProvider.future);
              },
              child: entriesAsync.when(
                loading: () => const LoadingState(itemHeight: 130),
                error: (error, _) => ScrollableEmptyState(
                  child: ErrorState(
                    message: ErrorState.describe(error),
                    onRetry: () => ref.invalidate(leaderboardProvider),
                  ),
                ),
                data: (entries) {
                  if (entries.isEmpty) {
                    return const ScrollableEmptyState(
                      child: EmptyState(
                        icon: Icons.leaderboard_rounded,
                        title: 'No scores for this period',
                        message:
                            'Pick a wider period, or start claiming and '
                            'working leads to get on the board.',
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.pagePadding,
                      12,
                      AppConstants.pagePadding,
                      24,
                    ),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => LeaderboardRow(
                      entry: entries[index],
                      isCurrentUser:
                          entries[index].employeeId == myEntry?.employeeId,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YourRankCard extends StatelessWidget {
  const _YourRankCard({required this.entry, required this.period});

  final LeaderboardEntry entry;
  final LeaderboardPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      borderColor: scheme.primary.withValues(alpha: 0.35),
      child: Column(
        children: [
          Row(
            children: [
              RankBadge(rank: entry.rank, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your rank', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 2),
                    Text(
                      entry.employeeName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      period.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.score}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: scheme.primary,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                  Text('points', style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              _Stat(label: 'Leads', value: entry.leadsTaken),
              _Stat(label: 'Calls', value: entry.callsMade),
              _Stat(label: 'Follow-ups', value: entry.followUpsCompleted),
              _Stat(label: 'Meetings', value: entry.meetings),
              _Stat(label: 'Won', value: entry.won),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
