import 'package:flutter/material.dart';

import '../../shared/models/enums.dart';

extension LeadPriorityColors on LeadPriority {
  Color get color => switch (this) {
        LeadPriority.high => Colors.red.shade700,
        LeadPriority.medium => Colors.amber.shade700,
        LeadPriority.low => Colors.green.shade700,
      };

  IconData get icon => switch (this) {
        LeadPriority.high => Icons.keyboard_double_arrow_up_rounded,
        LeadPriority.medium => Icons.drag_handle_rounded,
        LeadPriority.low => Icons.keyboard_double_arrow_down_rounded,
      };
}

LeadPriority leadPriorityFromString(String? value) {
  return LeadPriority.values.firstWhere(
    (p) => p.name.toLowerCase() == (value ?? '').toLowerCase(),
    orElse: () => LeadPriority.medium,
  );
}
