import 'package:flutter/material.dart';

import '../../../core/widgets/search_bar.dart';
import '../../../shared/models/enums.dart';

class PeriodFilterChips extends StatelessWidget {
  const PeriodFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final LeaderboardPeriod selected;
  final ValueChanged<LeaderboardPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChipRow<LeaderboardPeriod>(
      values: LeaderboardPeriod.values,
      selected: selected,
      labelBuilder: (value) => value.label,
      onSelected: onSelected,
    );
  }
}
