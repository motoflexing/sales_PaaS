import '../../shared/models/enums.dart';

const Object _sentinel = Object();

class AttendanceModel {
  const AttendanceModel({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.checkIn,
    this.checkOut,
    this.workingHours,
  });

  final String id;
  final String employeeId;
  final DateTime date;
  final DateTime checkIn;
  final DateTime? checkOut;
  final double? workingHours;

  bool get isOpen => checkOut == null;

  /// Hours worked so far, live while the session is still open.
  double get liveHours {
    final end = checkOut ?? DateTime.now();
    return end.difference(checkIn).inMinutes / 60.0;
  }

  AttendanceStatus get status {
    final hours = workingHours ?? liveHours;
    if (hours >= 6) return AttendanceStatus.present;
    return AttendanceStatus.halfDay;
  }

  /// Anyone punching in after 09:45 counts as late.
  bool get isLate =>
      checkIn.hour > 9 || (checkIn.hour == 9 && checkIn.minute > 45);

  AttendanceModel copyWith({
    String? id,
    String? employeeId,
    DateTime? date,
    DateTime? checkIn,
    Object? checkOut = _sentinel,
    Object? workingHours = _sentinel,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut == _sentinel ? this.checkOut : checkOut as DateTime?,
      workingHours: workingHours == _sentinel
          ? this.workingHours
          : workingHours as double?,
    );
  }
}
