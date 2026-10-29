import 'package:flutter/material.dart';

/// Semantic tokens that sit alongside the generated [ColorScheme] for the
/// domain concepts Material does not model (priority, pipeline stage, health).
class AppColors {
  const AppColors._();

  static const Color seed = Color(0xFF1A237E);

  static final Color priorityHigh = Colors.red.shade700;
  static final Color priorityMedium = Colors.amber.shade700;
  static final Color priorityLow = Colors.green.shade700;

  static final Color success = Colors.green.shade700;
  static final Color warning = Colors.orange.shade700;
  static final Color info = Colors.blue.shade700;

  static final Color checkIn = Colors.green.shade600;
  static final Color checkOut = Colors.orange.shade700;

  static const Color gold = Color(0xFFD4A017);
  static const Color silver = Color(0xFF9AA5B1);
  static const Color bronze = Color(0xFFB07338);

  /// Categorical chart palette. The slot ORDER is the colour-blind-safety
  /// mechanism, not decoration: adjacent pairs were validated for CVD and
  /// normal-vision separation in both themes. Assign slots in order and never
  /// cycle past the end - fold extra categories into "Other" instead.
  static const List<Color> _chartSeriesLight = [
    Color(0xFF2A78D6), // blue
    Color(0xFFEB6834), // orange
    Color(0xFF1BAF7A), // aqua
    Color(0xFFEDA100), // yellow
    Color(0xFFE87BA4), // magenta
    Color(0xFF008300), // green
  ];

  static const List<Color> _chartSeriesDark = [
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
    Color(0xFFC98500),
    Color(0xFFD55181),
    Color(0xFF008300),
  ];

  static List<Color> chartSeries(Brightness brightness) =>
      brightness == Brightness.dark ? _chartSeriesDark : _chartSeriesLight;

  /// Slot for the folded "everything else" category.
  static Color chartOther(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF6B6B66)
          : const Color(0xFF8A8A84);

  /// Single hue used whenever a chart shows one series of magnitudes.
  static Color chartAccent(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF3987E5)
          : const Color(0xFF2A78D6);

  /// Maximum categorical slices before folding into "Other".
  static const int maxChartCategories = 6;

  /// Tints a semantic colour so it reads as a badge background in either theme.
  static Color tint(Color color, Brightness brightness) =>
      color.withValues(alpha: brightness == Brightness.dark ? 0.22 : 0.12);
}
