import '../../shared/models/enums.dart';

const Object _sentinel = Object();

class LeadModel {
  const LeadModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.priority,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.company,
    this.contactPerson,
    this.alternatePhone,
    this.email,
    this.location,
    this.industry,
    this.source,
    this.leadType,
    this.assignedEmployeeId,
    this.publishedBy,
    this.publishedAt,
    this.claimedAt,
    this.managerRemark,
    this.lastActivityAt,
  });

  final String id;
  final String name;
  final String? company;
  final String? contactPerson;
  final String phone;
  final String? alternatePhone;
  final String? email;
  final String? location;
  final String? industry;
  final String? source;
  final String? leadType;
  final LeadPriority priority;
  final LeadStatus status;
  final String? assignedEmployeeId;
  final String? publishedBy;
  final DateTime? publishedAt;
  final DateTime? claimedAt;
  final String? managerRemark;
  final DateTime? lastActivityAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isAvailable =>
      status == LeadStatus.live && assignedEmployeeId == null;

  String get displayTitle => company?.trim().isNotEmpty == true ? company! : name;

  LeadModel copyWith({
    String? id,
    String? name,
    Object? company = _sentinel,
    Object? contactPerson = _sentinel,
    String? phone,
    Object? alternatePhone = _sentinel,
    Object? email = _sentinel,
    Object? location = _sentinel,
    Object? industry = _sentinel,
    Object? source = _sentinel,
    Object? leadType = _sentinel,
    LeadPriority? priority,
    LeadStatus? status,
    Object? assignedEmployeeId = _sentinel,
    Object? publishedBy = _sentinel,
    Object? publishedAt = _sentinel,
    Object? claimedAt = _sentinel,
    Object? managerRemark = _sentinel,
    Object? lastActivityAt = _sentinel,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeadModel(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company == _sentinel ? this.company : company as String?,
      contactPerson: contactPerson == _sentinel
          ? this.contactPerson
          : contactPerson as String?,
      phone: phone ?? this.phone,
      alternatePhone: alternatePhone == _sentinel
          ? this.alternatePhone
          : alternatePhone as String?,
      email: email == _sentinel ? this.email : email as String?,
      location: location == _sentinel ? this.location : location as String?,
      industry: industry == _sentinel ? this.industry : industry as String?,
      source: source == _sentinel ? this.source : source as String?,
      leadType: leadType == _sentinel ? this.leadType : leadType as String?,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assignedEmployeeId: assignedEmployeeId == _sentinel
          ? this.assignedEmployeeId
          : assignedEmployeeId as String?,
      publishedBy:
          publishedBy == _sentinel ? this.publishedBy : publishedBy as String?,
      publishedAt: publishedAt == _sentinel
          ? this.publishedAt
          : publishedAt as DateTime?,
      claimedAt:
          claimedAt == _sentinel ? this.claimedAt : claimedAt as DateTime?,
      managerRemark: managerRemark == _sentinel
          ? this.managerRemark
          : managerRemark as String?,
      lastActivityAt: lastActivityAt == _sentinel
          ? this.lastActivityAt
          : lastActivityAt as DateTime?,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is LeadModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
