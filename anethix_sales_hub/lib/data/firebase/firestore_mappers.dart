import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/enums.dart';
import '../models/activity_model.dart';
import '../models/attendance_model.dart';
import '../models/call_log_model.dart';
import '../models/follow_up_model.dart';
import '../models/lead_model.dart';
import '../models/remark_model.dart';
import '../models/user_model.dart';

/// Conversion between the plain model classes and Firestore documents. The
/// models stay free of any Firebase import; everything backend-shaped lives
/// here.
///
/// Two Firestore facts drive the defensive reads below:
///  * `FieldValue.serverTimestamp()` reads back as `null` on the local echo of
///    a write, before the server round-trip lands.
///  * A document written by an older build may be missing a field entirely.
///
/// Both cases fall back rather than throwing, so one malformed document can
/// never blank out a whole list.

DateTime? readTimestamp(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime readTimestampOr(Object? value, DateTime fallback) =>
    readTimestamp(value) ?? fallback;

Timestamp? writeTimestamp(DateTime? value) =>
    value == null ? null : Timestamp.fromDate(value);

T _enumFromName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

String? _trimToNull(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

// --------------------------------- User ---------------------------------

extension UserModelFirestore on UserModel {
  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'managerId': managerId,
        'isActive': isActive,
        'joinDate': writeTimestamp(joinDate),
        'createdAt': writeTimestamp(createdAt),
        'updatedAt': writeTimestamp(updatedAt),
        'avatarUrl': avatarUrl,
      };
}

UserModel userFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final createdAt = readTimestampOr(data['createdAt'], epoch);
  return UserModel(
    id: doc.id,
    name: (data['name'] as String?) ?? 'Unknown',
    email: (data['email'] as String?) ?? '',
    phone: (data['phone'] as String?) ?? '',
    role: _enumFromName(UserRole.values, data['role'], UserRole.employee),
    managerId: _trimToNull(data['managerId']),
    isActive: (data['isActive'] as bool?) ?? true,
    joinDate: readTimestampOr(data['joinDate'], createdAt),
    createdAt: createdAt,
    updatedAt: readTimestampOr(data['updatedAt'], createdAt),
    avatarUrl: _trimToNull(data['avatarUrl']),
  );
}

// --------------------------------- Lead ---------------------------------

extension LeadModelFirestore on LeadModel {
  Map<String, dynamic> toMap() => {
        'name': name,
        'company': company,
        'contactPerson': contactPerson,
        'phone': phone,
        'alternatePhone': alternatePhone,
        'email': email,
        'location': location,
        'industry': industry,
        'source': source,
        'leadType': leadType,
        'priority': priority.name,
        'status': status.name,
        'assignedEmployeeId': assignedEmployeeId,
        'publishedBy': publishedBy,
        'publishedAt': writeTimestamp(publishedAt),
        'claimedAt': writeTimestamp(claimedAt),
        'managerRemark': managerRemark,
        'lastActivityAt': writeTimestamp(lastActivityAt),
        'createdBy': createdBy,
        'createdAt': writeTimestamp(createdAt),
        'updatedAt': writeTimestamp(updatedAt),
      };
}

LeadModel leadFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final createdAt =
      readTimestampOr(data['createdAt'], DateTime.fromMillisecondsSinceEpoch(0));
  return LeadModel(
    id: doc.id,
    name: (data['name'] as String?) ?? 'Untitled lead',
    company: _trimToNull(data['company']),
    contactPerson: _trimToNull(data['contactPerson']),
    phone: (data['phone'] as String?) ?? '',
    alternatePhone: _trimToNull(data['alternatePhone']),
    email: _trimToNull(data['email']),
    location: _trimToNull(data['location']),
    industry: _trimToNull(data['industry']),
    source: _trimToNull(data['source']),
    leadType: _trimToNull(data['leadType']),
    priority:
        _enumFromName(LeadPriority.values, data['priority'], LeadPriority.medium),
    status: _enumFromName(LeadStatus.values, data['status'], LeadStatus.draft),
    assignedEmployeeId: _trimToNull(data['assignedEmployeeId']),
    publishedBy: _trimToNull(data['publishedBy']),
    publishedAt: readTimestamp(data['publishedAt']),
    claimedAt: readTimestamp(data['claimedAt']),
    managerRemark: _trimToNull(data['managerRemark']),
    lastActivityAt: readTimestamp(data['lastActivityAt']),
    createdBy: (data['createdBy'] as String?) ?? '',
    createdAt: createdAt,
    updatedAt: readTimestampOr(data['updatedAt'], createdAt),
  );
}

// -------------------------------- CallLog --------------------------------

extension CallLogModelFirestore on CallLogModel {
  Map<String, dynamic> toMap() => {
        'leadId': leadId,
        'employeeId': employeeId,
        'date': writeTimestamp(date),
        'outcome': outcome.name,
        'remark': remark,
        'followUpDate': writeTimestamp(followUpDate),
        'durationSeconds': durationSeconds,
        'createdAt': writeTimestamp(createdAt),
      };
}

CallLogModel callLogFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final createdAt =
      readTimestampOr(data['createdAt'], DateTime.fromMillisecondsSinceEpoch(0));
  return CallLogModel(
    id: doc.id,
    leadId: (data['leadId'] as String?) ?? '',
    employeeId: (data['employeeId'] as String?) ?? '',
    date: readTimestampOr(data['date'], createdAt),
    outcome:
        _enumFromName(CallOutcome.values, data['outcome'], CallOutcome.noAnswer),
    remark: _trimToNull(data['remark']),
    followUpDate: readTimestamp(data['followUpDate']),
    durationSeconds: (data['durationSeconds'] as num?)?.toInt(),
    createdAt: createdAt,
  );
}

// -------------------------------- FollowUp --------------------------------

extension FollowUpModelFirestore on FollowUpModel {
  Map<String, dynamic> toMap() => {
        'leadId': leadId,
        'employeeId': employeeId,
        'scheduledAt': writeTimestamp(scheduledAt),
        'completedAt': writeTimestamp(completedAt),
        'status': status.name,
        'remark': remark,
        'createdAt': writeTimestamp(createdAt),
      };
}

FollowUpModel followUpFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final createdAt =
      readTimestampOr(data['createdAt'], DateTime.fromMillisecondsSinceEpoch(0));
  return FollowUpModel(
    id: doc.id,
    leadId: (data['leadId'] as String?) ?? '',
    employeeId: (data['employeeId'] as String?) ?? '',
    scheduledAt: readTimestampOr(data['scheduledAt'], createdAt),
    completedAt: readTimestamp(data['completedAt']),
    status: _enumFromName(
      FollowUpStatus.values,
      data['status'],
      FollowUpStatus.pending,
    ),
    remark: _trimToNull(data['remark']),
    createdAt: createdAt,
  );
}

// ------------------------------- Attendance -------------------------------

extension AttendanceModelFirestore on AttendanceModel {
  Map<String, dynamic> toMap() => {
        'employeeId': employeeId,
        'date': writeTimestamp(date),
        'dateKey': attendanceDateKey(date),
        'checkIn': writeTimestamp(checkIn),
        'checkOut': writeTimestamp(checkOut),
        'workingHours': workingHours,
      };
}

/// A calendar-day key (`2026-09-05`) so "did this employee already check in
/// today" is a single equality query instead of a range scan.
String attendanceDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

AttendanceModel attendanceFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final date = readTimestampOr(data['date'], epoch);
  return AttendanceModel(
    id: doc.id,
    employeeId: (data['employeeId'] as String?) ?? '',
    date: date,
    checkIn: readTimestampOr(data['checkIn'], date),
    checkOut: readTimestamp(data['checkOut']),
    workingHours: (data['workingHours'] as num?)?.toDouble(),
  );
}

// -------------------------------- Activity --------------------------------

extension ActivityModelFirestore on ActivityModel {
  Map<String, dynamic> toMap() => {
        'leadId': leadId,
        'userId': userId,
        'userName': userName,
        'action': action,
        'description': description,
        'createdAt': writeTimestamp(createdAt),
      };
}

ActivityModel activityFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return ActivityModel(
    id: doc.id,
    leadId: _trimToNull(data['leadId']),
    userId: (data['userId'] as String?) ?? '',
    userName: (data['userName'] as String?) ?? 'Unknown',
    action: (data['action'] as String?) ?? '',
    description: (data['description'] as String?) ?? '',
    createdAt: readTimestampOr(
      data['createdAt'],
      DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );
}

// --------------------------------- Remark ---------------------------------

extension RemarkModelFirestore on RemarkModel {
  Map<String, dynamic> toMap() => {
        'leadId': leadId,
        'authorId': authorId,
        'authorName': authorName,
        'text': text,
        'createdAt': writeTimestamp(createdAt),
      };
}

RemarkModel remarkFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return RemarkModel(
    id: doc.id,
    leadId: (data['leadId'] as String?) ?? '',
    authorId: (data['authorId'] as String?) ?? '',
    authorName: (data['authorName'] as String?) ?? 'Unknown',
    text: (data['text'] as String?) ?? '',
    createdAt: readTimestampOr(
      data['createdAt'],
      DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );
}

/// Maps a query snapshot to models, skipping any document that cannot be
/// parsed rather than failing the whole page.
List<T> mapDocs<T>(
  QuerySnapshot<Map<String, dynamic>> snapshot,
  T Function(DocumentSnapshot<Map<String, dynamic>>) mapper,
) {
  final out = <T>[];
  for (final doc in snapshot.docs) {
    try {
      out.add(mapper(doc));
    } on Object {
      continue;
    }
  }
  return out;
}
