import '../../shared/models/enums.dart';

const Object _sentinel = Object();

class CallLogModel {
  const CallLogModel({
    required this.id,
    required this.leadId,
    required this.employeeId,
    required this.date,
    required this.outcome,
    required this.createdAt,
    this.remark,
    this.followUpDate,
    this.durationSeconds,
  });

  final String id;
  final String leadId;
  final String employeeId;
  final DateTime date;
  final CallOutcome outcome;
  final String? remark;
  final DateTime? followUpDate;
  final int? durationSeconds;
  final DateTime createdAt;

  CallLogModel copyWith({
    String? id,
    String? leadId,
    String? employeeId,
    DateTime? date,
    CallOutcome? outcome,
    Object? remark = _sentinel,
    Object? followUpDate = _sentinel,
    Object? durationSeconds = _sentinel,
    DateTime? createdAt,
  }) {
    return CallLogModel(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      outcome: outcome ?? this.outcome,
      remark: remark == _sentinel ? this.remark : remark as String?,
      followUpDate: followUpDate == _sentinel
          ? this.followUpDate
          : followUpDate as DateTime?,
      durationSeconds: durationSeconds == _sentinel
          ? this.durationSeconds
          : durationSeconds as int?,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
