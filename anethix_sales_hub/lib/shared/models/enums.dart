/// Central enum definitions shared across the whole app.
library;

enum UserRole { admin, manager, employee }

/// Ordered along the sales pipeline. `lost` is terminal and reachable from
/// anywhere, so it deliberately sits at the end.
enum LeadStatus {
  draft,
  live,
  claimed,
  contacted,
  interested,
  followUp,
  meeting,
  proposal,
  won,
  lost,
}

enum LeadPriority { high, medium, low }

enum CallOutcome {
  connectedInterested,
  connectedNotInterested,
  followUpRequired,
  noAnswer,
  busy,
  callBackLater,
  wrongNumber,
}

enum FollowUpStatus { pending, completed, rescheduled, overdue }

enum AttendanceStatus { present, absent, halfDay }

enum LeaderboardPeriod { today, thisWeek, thisMonth, thisQuarter, allTime }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.manager => 'Manager',
        UserRole.employee => 'Employee',
      };

  String get storageKey => name;
}

extension LeadPriorityX on LeadPriority {
  String get label => switch (this) {
        LeadPriority.high => 'High',
        LeadPriority.medium => 'Medium',
        LeadPriority.low => 'Low',
      };
}

extension LeadStatusX on LeadStatus {
  String get label => switch (this) {
        LeadStatus.draft => 'Draft',
        LeadStatus.live => 'Live',
        LeadStatus.claimed => 'Claimed',
        LeadStatus.contacted => 'Contacted',
        LeadStatus.interested => 'Interested',
        LeadStatus.followUp => 'Follow-up',
        LeadStatus.meeting => 'Meeting',
        LeadStatus.proposal => 'Proposal',
        LeadStatus.won => 'Won',
        LeadStatus.lost => 'Lost',
      };
}

extension CallOutcomeX on CallOutcome {
  String get label => switch (this) {
        CallOutcome.connectedInterested => 'Connected - Interested',
        CallOutcome.connectedNotInterested => 'Connected - Not Interested',
        CallOutcome.followUpRequired => 'Follow-up Required',
        CallOutcome.noAnswer => 'No Answer',
        CallOutcome.busy => 'Busy',
        CallOutcome.callBackLater => 'Call Back Later',
        CallOutcome.wrongNumber => 'Wrong Number',
      };

  /// Outcomes that count as a successful conversation for scoring.
  bool get isConnected =>
      this == CallOutcome.connectedInterested ||
      this == CallOutcome.connectedNotInterested ||
      this == CallOutcome.followUpRequired;
}

extension FollowUpStatusX on FollowUpStatus {
  String get label => switch (this) {
        FollowUpStatus.pending => 'Pending',
        FollowUpStatus.completed => 'Completed',
        FollowUpStatus.rescheduled => 'Rescheduled',
        FollowUpStatus.overdue => 'Overdue',
      };
}

extension AttendanceStatusX on AttendanceStatus {
  String get label => switch (this) {
        AttendanceStatus.present => 'Present',
        AttendanceStatus.absent => 'Absent',
        AttendanceStatus.halfDay => 'Half-day',
      };
}

extension LeaderboardPeriodX on LeaderboardPeriod {
  String get label => switch (this) {
        LeaderboardPeriod.today => 'Today',
        LeaderboardPeriod.thisWeek => 'This Week',
        LeaderboardPeriod.thisMonth => 'This Month',
        LeaderboardPeriod.thisQuarter => 'This Quarter',
        LeaderboardPeriod.allTime => 'All Time',
      };
}
