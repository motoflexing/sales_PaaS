import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class AppDate {
  const AppDate._();

  static final DateFormat _day = DateFormat('d MMM yyyy');
  static final DateFormat _dayShort = DateFormat('d MMM');
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _dayTime = DateFormat('d MMM, h:mm a');
  static final DateFormat _weekday = DateFormat('EEE, d MMM');
  static final DateFormat _monthDay = DateFormat('d/M');

  static String day(DateTime? at) => at == null ? '-' : _day.format(at);
  static String dayShort(DateTime? at) => at == null ? '-' : _dayShort.format(at);
  static String time(DateTime? at) => at == null ? '-' : _time.format(at);
  static String dayTime(DateTime? at) => at == null ? '-' : _dayTime.format(at);
  static String weekday(DateTime? at) => at == null ? '-' : _weekday.format(at);
  static String chartLabel(DateTime at) => _monthDay.format(at);

  static String ago(DateTime? at) =>
      at == null ? '-' : timeago.format(at, locale: 'en_short');

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime at) => isSameDay(at, DateTime.now());

  static DateTime startOfDay(DateTime at) =>
      DateTime(at.year, at.month, at.day);

  static DateTime startOfWeek(DateTime at) {
    final d = startOfDay(at);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// Human label for a scheduled slot: "Today, 3:00 PM" / "Tomorrow, 10:00 AM".
  static String relativeSlot(DateTime at) {
    final now = DateTime.now();
    final today = startOfDay(now);
    final target = startOfDay(at);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today, ${_time.format(at)}';
    if (diff == 1) return 'Tomorrow, ${_time.format(at)}';
    if (diff == -1) return 'Yesterday, ${_time.format(at)}';
    return _dayTime.format(at);
  }

  /// "3 days overdue" / "5 hours overdue" for a slot already in the past.
  static String overdueBy(DateTime scheduledAt) {
    final diff = DateTime.now().difference(scheduledAt);
    if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} overdue';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} overdue';
    }
    final mins = diff.inMinutes.clamp(1, 59);
    return '$mins min overdue';
  }

  static String duration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  static String hours(double? value) =>
      value == null ? '-' : '${value.toStringAsFixed(1)} h';

  /// Last [count] days ending today, oldest first.
  static List<DateTime> lastDays(int count) {
    final today = startOfDay(DateTime.now());
    return [
      for (var i = count - 1; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
  }

  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
