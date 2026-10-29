import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../data/models/lead_model.dart';
import '../../../data/repositories/lead_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/live_leads_provider.dart';
import '../widgets/live_lead_card.dart';

class LiveLeadsScreen extends ConsumerStatefulWidget {
  const LiveLeadsScreen({super.key});

  @override
  ConsumerState<LiveLeadsScreen> createState() => _LiveLeadsScreenState();
}

class _LiveLeadsScreenState extends ConsumerState<LiveLeadsScreen> {
  bool _isSearching = false;
  String? _claimingLeadId;

  Future<void> _claim(LeadModel lead) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Claim this lead?',
      message: "You'll be responsible for contacting ${lead.name}"
          "${lead.company == null ? '' : ' at ${lead.company}'}.",
      confirmLabel: 'Take lead',
      icon: Icons.flash_on_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _claimingLeadId = lead.id);
    try {
      await ref.read(liveLeadsProvider.notifier).claim(lead.id, user.id);
      if (!mounted) return;
      context.showInfo(
        'Lead claimed - ${lead.name} is yours.',
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => context.push(Routes.employeeLead(lead.id)),
        ),
      );
      context.go(Routes.employeeMyLeads);
    } on LeadAlreadyClaimedException {
      if (mounted) context.showError('This lead has already been claimed.');
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _claimingLeadId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(filteredLiveLeadsProvider);
    final query = ref.watch(liveLeadsQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? AppSearchField(
                autofocus: true,
                hintText: 'Search company, city, contact',
                initialValue: query,
                onChanged: (value) =>
                    ref.read(liveLeadsQueryProvider.notifier).state = value,
              )
            : const Text('Live Leads'),
        titleSpacing: _isSearching ? 8 : null,
        centerTitle: !_isSearching,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _isSearching ? 'Close search' : 'Search',
            onPressed: () {
              setState(() => _isSearching = !_isSearching);
              if (!_isSearching) {
                ref.read(liveLeadsQueryProvider.notifier).state = '';
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(liveLeadsProvider.notifier).refresh(),
        child: leadsAsync.when(
          loading: () => const LoadingState(itemHeight: 190),
          error: (error, _) => ScrollableEmptyState(
            child: ErrorState(
              message: ErrorState.describe(error),
              onRetry: () => ref.read(liveLeadsProvider.notifier).refresh(),
            ),
          ),
          data: (leads) {
            if (leads.isEmpty) {
              return ScrollableEmptyState(
                child: EmptyState(
                  icon: query.isEmpty
                      ? Icons.podcasts_rounded
                      : Icons.search_off_rounded,
                  title: query.isEmpty
                      ? 'No leads available right now'
                      : 'No leads match "$query"',
                  message: query.isEmpty
                      ? 'Your manager publishes new leads through the day. '
                          'Pull down to refresh, or check back soon.'
                      : 'Try a different company, city or contact name.',
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
              itemCount: leads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final lead = leads[index];
                return LiveLeadCard(
                  lead: lead,
                  isClaiming: _claimingLeadId == lead.id,
                  onTake: () => _claim(lead),
                )
                    .animate()
                    .fadeIn(duration: 220.ms, delay: (index * 35).ms)
                    .slideY(begin: 0.06, end: 0);
              },
            );
          },
        ),
      ),
    );
  }
}
