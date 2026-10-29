const Object _sentinel = Object();

/// Canonical action keys used by the timeline renderer.
class ActivityAction {
  const ActivityAction._();

  static const String leadCreated = 'lead_created';
  static const String leadPublished = 'lead_published';
  static const String leadClaimed = 'lead_claimed';
  static const String callLogged = 'call_logged';
  static const String remarkAdded = 'remark_added';
  static const String statusChanged = 'status_changed';
  static const String priorityChanged = 'priority_changed';
  static const String followUpScheduled = 'follow_up_scheduled';
  static const String followUpCompleted = 'follow_up_completed';
  static const String followUpRescheduled = 'follow_up_rescheduled';
  static const String leadImported = 'lead_imported';
  static const String checkedIn = 'checked_in';
  static const String checkedOut = 'checked_out';
  static const String userCreated = 'user_created';
}

class ActivityModel {
  const ActivityModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.description,
    required this.createdAt,
    this.leadId,
  });

  final String id;
  final String? leadId;
  final String userId;
  final String userName;
  final String action;
  final String description;
  final DateTime createdAt;

  ActivityModel copyWith({
    String? id,
    Object? leadId = _sentinel,
    String? userId,
    String? userName,
    String? action,
    String? description,
    DateTime? createdAt,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      leadId: leadId == _sentinel ? this.leadId : leadId as String?,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      action: action ?? this.action,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
