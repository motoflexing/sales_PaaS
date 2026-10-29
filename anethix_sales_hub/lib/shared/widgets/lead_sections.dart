import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/priority_badge.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/activity_model.dart';
import '../../data/models/call_log_model.dart';
import '../../data/models/lead_model.dart';
import '../../data/models/remark_model.dart';
import '../../features/employee/widgets/call_outcome_selector.dart';

/// Contact block shared by the employee workspace and the manager detail view.
class LeadHeaderCard extends StatelessWidget {
  const LeadHeaderCard({
    super.key,
    required this.lead,
    this.onCallPrimary,
    this.onCallAlternate,
  });

  final LeadModel lead;
  final VoidCallback? onCallPrimary;
  final VoidCallback? onCallAlternate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead.name, style: theme.textTheme.titleLarge),
                    if (lead.company != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        lead.company!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(status: lead.status),
                  const SizedBox(height: 6),
                  PriorityBadge(priority: lead.priority, compact: true),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          if (lead.contactPerson != null)
            DetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Contact person',
              value: lead.contactPerson!,
            ),
          DetailRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: lead.phone,
            onTap: onCallPrimary,
            trailing: onCallPrimary == null
                ? null
                : Icon(Icons.call_rounded, size: 18, color: scheme.primary),
          ),
          if (lead.alternatePhone != null)
            DetailRow(
              icon: Icons.phone_forwarded_outlined,
              label: 'Alternate phone',
              value: lead.alternatePhone!,
              onTap: onCallAlternate,
            ),
          if (lead.email != null)
            DetailRow(
              icon: Icons.alternate_email_rounded,
              label: 'Email',
              value: lead.email!,
            ),
          if (lead.location != null)
            DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: lead.location!,
            ),
          if (lead.industry != null)
            DetailRow(
              icon: Icons.business_center_outlined,
              label: 'Industry',
              value: lead.industry!,
            ),
          if (lead.source != null)
            DetailRow(
              icon: Icons.share_outlined,
              label: 'Source',
              value: lead.source!,
            ),
          if (lead.leadType != null)
            DetailRow(
              icon: Icons.category_outlined,
              label: 'Lead type',
              value: lead.leadType!,
            ),
          DetailRow(
            icon: Icons.event_outlined,
            label: 'Created',
            value: AppDate.dayTime(lead.createdAt),
          ),
          if (lead.claimedAt != null)
            DetailRow(
              icon: Icons.how_to_reg_outlined,
              label: 'Claimed',
              value: AppDate.dayTime(lead.claimedAt),
            ),
        ],
      ),
    );
  }
}

class CallHistorySection extends StatelessWidget {
  const CallHistorySection({super.key, required this.calls});

  final List<CallLogModel> calls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (calls.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.phone_disabled_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No calls logged for this lead yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < calls.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CallOutcomeChip(outcome: calls[i].outcome),
                      const Spacer(),
                      Text(
                        AppDate.ago(calls[i].date),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (calls[i].remark != null) ...[
                    const SizedBox(height: 6),
                    Text(calls[i].remark!, style: theme.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppDate.dayTime(calls[i].date),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (calls[i].durationSeconds != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppDate.duration(
                            Duration(seconds: calls[i].durationSeconds!),
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RemarksSection extends StatelessWidget {
  const RemarksSection({super.key, required this.remarks});

  final List<RemarkModel> remarks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (remarks.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No remarks yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < remarks.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InitialsAvatar(name: remarks[i].authorName, radius: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                remarks[i].authorName,
                                style: theme.textTheme.labelLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              AppDate.ago(remarks[i].createdAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          remarks[i].text,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reverse-chronological activity feed for a lead or a person.
class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({
    super.key,
    required this.activities,
    this.emptyMessage = 'Nothing has happened here yet.',
    this.showAuthor = true,
  });

  final List<ActivityModel> activities;
  final String emptyMessage;
  final bool showAuthor;

  static IconData iconFor(String action) => switch (action) {
        ActivityAction.leadCreated => Icons.add_circle_outline_rounded,
        ActivityAction.leadPublished => Icons.podcasts_rounded,
        ActivityAction.leadClaimed => Icons.how_to_reg_rounded,
        ActivityAction.callLogged => Icons.phone_in_talk_rounded,
        ActivityAction.remarkAdded => Icons.chat_bubble_outline_rounded,
        ActivityAction.statusChanged => Icons.swap_horiz_rounded,
        ActivityAction.priorityChanged => Icons.flag_outlined,
        ActivityAction.followUpScheduled => Icons.event_available_rounded,
        ActivityAction.followUpCompleted => Icons.task_alt_rounded,
        ActivityAction.followUpRescheduled => Icons.update_rounded,
        ActivityAction.leadImported => Icons.upload_file_rounded,
        ActivityAction.checkedIn => Icons.login_rounded,
        ActivityAction.checkedOut => Icons.logout_rounded,
        ActivityAction.userCreated => Icons.person_add_alt_rounded,
        _ => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (activities.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.timeline_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                emptyMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          for (var i = 0; i < activities.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primaryContainer.withValues(alpha: 0.5),
                        ),
                        child: Icon(
                          iconFor(activities[i].action),
                          size: 15,
                          color: scheme.primary,
                        ),
                      ),
                      if (i != activities.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: scheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i == activities.length - 1 ? 0 : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activities[i].description,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            showAuthor
                                ? '${activities[i].userName} · '
                                    '${AppDate.ago(activities[i].createdAt)}'
                                : AppDate.ago(activities[i].createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Manager note attached to a lead when it was published.
class ManagerNoteCard extends StatelessWidget {
  const ManagerNoteCard({super.key, required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      color: scheme.secondaryContainer.withValues(alpha: 0.45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign_rounded, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Note from your manager', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(note, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick sanity helper so detail screens can show "-" for blank fields.
String detailOrDash(String? value) => value.orDash();
