import 'package:flutter/material.dart';

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Size get screenSize => MediaQuery.sizeOf(this);

  void showSuccess(String message) => _snack(message);

  void showInfo(String message, {SnackBarAction? action}) =>
      _snack(message, action: action);

  void showError(String message) => _snack(
        message,
        background: colors.error,
        foreground: colors.onError,
      );

  void _snack(
    String message, {
    Color? background,
    Color? foreground,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: foreground == null ? null : TextStyle(color: foreground),
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          action: action,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}

extension StringX on String {
  String get capitalised =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  String truncate(int max) =>
      length <= max ? this : '${substring(0, max).trimRight()}...';

  bool containsIgnoreCase(String query) =>
      toLowerCase().contains(query.toLowerCase());
}

extension NullableStringX on String? {
  bool get isBlank => this == null || this!.trim().isEmpty;
  bool get isFilled => !isBlank;
  String orDash() => isBlank ? '-' : this!;
}

extension IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }

  int countWhere(bool Function(T) test) {
    var n = 0;
    for (final item in this) {
      if (test(item)) n++;
    }
    return n;
  }
}

extension NumX on num {
  /// Percentage of [total], guarding the empty-denominator case.
  double percentOf(num total) => total == 0 ? 0 : (this / total) * 100;
}

/// Repository exceptions carry a readable `message`; anything else falls back
/// to a generic line rather than leaking a stack trace into the UI.
String describeError(Object error) {
  final text = error.toString().replaceFirst('Exception: ', '').trim();
  if (text.isEmpty || text.length > 180) {
    return 'Something went wrong. Please try again.';
  }
  return text;
}
