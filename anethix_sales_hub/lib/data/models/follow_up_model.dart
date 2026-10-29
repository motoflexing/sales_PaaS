import '../../shared/models/enums.dart';

const Object _sentinel = Object();

class FollowUpModel {
  const FollowUpModel({
    required this.id,
    required this.leadId,
    required this.employeeId,
    required this.scheduledAt,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.remark,
  });

  final String id;
  final String leadId;
  final String employeeId;
  final DateTime scheduledAt;
  final DateTime? completedAt;
  final FollowUpStatus status;
  final String? remark;
  final DateTime createdAt;

  bool get isOpen =>
      status == FollowUpStatus.pending ||
      status == FollowUpStatus.rescheduled ||
      status == FollowUpStatus.overdue;

  FollowUpModel copyWith({
    String? id,
    String? leadId,
    String? employeeId,
    DateTime? scheduledAt,
    Object? completedAt = _sentinel,
    FollowUpStatus? status,
    Object? remark = _sentinel,
    DateTime? createdAt,
  }) {
    return FollowUpModel(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      employeeId: employeeId ?? this.employeeId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      completedAt: completedAt == _sentinel
          ? this.completedAt
          : completedAt as DateTime?,
      status: status ?? this.status,
      remark: remark == _sentinel ? this.remark : remark as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
