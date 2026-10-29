import 'package:flutter/material.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/lead_model.dart';
import '../providers/my_leads_provider.dart';

/// Overlays a remark marker on the top-right of [child].
///
/// Nothing is drawn when there are no remarks, so an untouched lead's button
/// looks exactly as it always did. Remarks the reader has not seen get a
/// counted pill; once everything has been read the count collapses to a plain
/// dot, which still says "there is history here" at a glance.
class RemarkIndicator extends StatelessWidget {
  const RemarkIndicator({super.key, required this.child, this.badge});

  final Widget child;
  final RemarkBadge? badge;

  @override
  Widget build(BuildContext context) {
    final badge = this.badge;
    if (badge == null || !badge.hasAny) return child;

    final scheme = Theme.of(context).colorScheme;
    final hasUnread = badge.unread > 0;
    // Tertiary reads as "new" against the primary-coloured action icons.
    final color = hasUnread ? scheme.tertiary : scheme.primary;
    final label = badge.unread > 99 ? '99+' : '${badge.unread}';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -6,
          child: hasUnread
              ? Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.surface, width: 1.5),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: scheme.onTertiary,
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ],
    );
  }
}

class MyLeadCard extends StatelessWidget {
  const MyLeadCard({
    super.key,
    required this.lead,
    required this.onTap,
    required this.onCall,
    required this.onRemark,
    required this.onStatus,
    required this.onFollowUp,
    this.lastCallAt,
    this.nextFollowUpAt,
    this.remarkBadge,
  });

  final LeadModel lead;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onRemark;
  final VoidCallback onStatus;
  final VoidCallback onFollowUp;
  final DateTime? lastCallAt;
  final DateTime? nextFollowUpAt;

  /// Remark state for this lead, or null while the counts are still loading.
  final RemarkBadge? remarkBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOverdue =
        nextFollowUpAt != null && nextFollowUpAt!.isBefore(DateTime.now());

    return AppCard(
      onTap: onTap,
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
                    Text(
                      lead.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lead.company != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        lead.company!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PriorityBadge(priority: lead.priority, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.phone_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(lead.phone, style: theme.textTheme.bodyMedium),
              const Spacer(),
              StatusBadge(status: lead.status, compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimelineNote(
                  icon: Icons.history_rounded,
                  label: lastCallAt == null
                      ? 'No calls yet'
                      : 'Last call ${AppDate.ago(lastCallAt)}',
                ),
              ),
              if (nextFollowUpAt != null)
                Expanded(
                  child: _TimelineNote(
                    icon: Icons.event_rounded,
                    label: isOverdue
                        ? AppDate.overdueBy(nextFollowUpAt!)
                        : AppDate.relativeSlot(nextFollowUpAt!),
                    color: isOverdue ? scheme.error : null,
                  ),
                ),
            ],
          ),
          const Divider(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Action(icon: Icons.phone_rounded, label: 'Call', onTap: onCall),
              _Action(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Remark',
                onTap: onRemark,
                badge: remarkBadge,
              ),
              _Action(
                icon: Icons.playlist_add_check_rounded,
                label: 'Status',
                onTap: onStatus,
              ),
              _Action(
                icon: Icons.event_available_rounded,
                label: 'Follow-up',
                onTap: onFollowUp,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineNote extends StatelessWidget {
  const _TimelineNote({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 13, color: tone),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tone,
              fontWeight: color != null ? FontWeight.w700 : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Null, or a badge with nothing to show, leaves the button exactly as it is.
  final RemarkBadge? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RemarkIndicator(
              badge: badge,
              child: Icon(icon, size: 20, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
