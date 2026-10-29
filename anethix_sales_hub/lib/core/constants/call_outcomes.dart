import 'package:flutter/material.dart';

import '../../shared/models/enums.dart';

extension CallOutcomeVisuals on CallOutcome {
  Color get color => switch (this) {
        CallOutcome.connectedInterested => Colors.green.shade700,
        CallOutcome.connectedNotInterested => Colors.deepOrange.shade700,
        CallOutcome.followUpRequired => Colors.blue.shade700,
        CallOutcome.noAnswer => Colors.blueGrey.shade600,
        CallOutcome.busy => Colors.amber.shade800,
        CallOutcome.callBackLater => Colors.purple.shade600,
        CallOutcome.wrongNumber => Colors.red.shade700,
      };

  IconData get icon => switch (this) {
        CallOutcome.connectedInterested => Icons.sentiment_very_satisfied_rounded,
        CallOutcome.connectedNotInterested => Icons.sentiment_dissatisfied_rounded,
        CallOutcome.followUpRequired => Icons.event_repeat_rounded,
        CallOutcome.noAnswer => Icons.phone_missed_rounded,
        CallOutcome.busy => Icons.phone_paused_rounded,
        CallOutcome.callBackLater => Icons.schedule_rounded,
        CallOutcome.wrongNumber => Icons.phone_disabled_rounded,
      };
}
