import 'package:flutter/material.dart';

import '../../shared/models/enums.dart';

extension LeadStatusVisuals on LeadStatus {
  Color get color => switch (this) {
        LeadStatus.draft => Colors.blueGrey.shade500,
        LeadStatus.live => Colors.teal.shade600,
        LeadStatus.claimed => Colors.indigo.shade500,
        LeadStatus.contacted => Colors.blue.shade600,
        LeadStatus.interested => Colors.lightGreen.shade700,
        LeadStatus.followUp => Colors.purple.shade500,
        LeadStatus.meeting => Colors.deepPurple.shade500,
        LeadStatus.proposal => Colors.orange.shade700,
        LeadStatus.won => Colors.green.shade700,
        LeadStatus.lost => Colors.red.shade700,
      };

  IconData get icon => switch (this) {
        LeadStatus.draft => Icons.edit_note_rounded,
        LeadStatus.live => Icons.podcasts_rounded,
        LeadStatus.claimed => Icons.person_add_alt_1_rounded,
        LeadStatus.contacted => Icons.phone_in_talk_rounded,
        LeadStatus.interested => Icons.thumb_up_alt_rounded,
        LeadStatus.followUp => Icons.event_repeat_rounded,
        LeadStatus.meeting => Icons.groups_rounded,
        LeadStatus.proposal => Icons.description_rounded,
        LeadStatus.won => Icons.emoji_events_rounded,
        LeadStatus.lost => Icons.cancel_rounded,
      };
}

/// Stages shown in the pipeline stepper. `lost` is excluded because it is an
/// off-ramp rather than a stage.
const List<LeadStatus> pipelineStages = [
  LeadStatus.draft,
  LeadStatus.live,
  LeadStatus.claimed,
  LeadStatus.contacted,
  LeadStatus.interested,
  LeadStatus.followUp,
  LeadStatus.meeting,
  LeadStatus.proposal,
  LeadStatus.won,
];

/// Statuses an employee is allowed to work a claimed lead through.
const List<LeadStatus> employeeWorkableStatuses = [
  LeadStatus.claimed,
  LeadStatus.contacted,
  LeadStatus.interested,
  LeadStatus.followUp,
  LeadStatus.meeting,
  LeadStatus.proposal,
  LeadStatus.won,
  LeadStatus.lost,
];

/// The status machine: a lead may only move forward through the pipeline,
/// except that anything still in play can be marked lost.
Set<LeadStatus> allowedNextStatuses(LeadStatus current) {
  if (current == LeadStatus.won || current == LeadStatus.lost) {
    return const <LeadStatus>{};
  }
  final index = pipelineStages.indexOf(current);
  final next = <LeadStatus>{};
  if (index != -1) {
    next.addAll(pipelineStages.skip(index + 1));
  }
  // Draft/live are manager-side transitions and are not employee choices.
  next.removeWhere((s) => s == LeadStatus.draft || s == LeadStatus.live);
  if (current != LeadStatus.draft && current != LeadStatus.live) {
    next.add(LeadStatus.lost);
  }
  return next;
}

bool isTerminal(LeadStatus status) =>
    status == LeadStatus.won || status == LeadStatus.lost;

LeadStatus leadStatusFromString(String? value) {
  return LeadStatus.values.firstWhere(
    (s) => s.name.toLowerCase() == (value ?? '').toLowerCase(),
    orElse: () => LeadStatus.draft,
  );
}
