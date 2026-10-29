import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/activity_model.dart';
import '../../../data/models/call_log_model.dart';
import '../../../data/models/follow_up_model.dart';
import '../../../data/models/lead_model.dart';
import '../../../data/models/remark_model.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/shared_providers.dart';
import '../../auth/providers/auth_provider.dart';

/// Everything a lead detail/work screen needs, fetched together.
class LeadWorkspace {
  const LeadWorkspace({
    required this.lead,
    required this.calls,
    required this.remarks,
    required this.followUps,
    required this.activities,
    this.assignedEmployee,
  });

  final LeadModel lead;
  final List<CallLogModel> calls;
  final List<RemarkModel> remarks;
  final List<FollowUpModel> followUps;
  final List<ActivityModel> activities;
  final UserModel? assignedEmployee;

  CallLogModel? get lastCall => calls.isEmpty ? null : calls.first;

  FollowUpModel? get nextFollowUp {
    final open = followUps.where((f) => f.isOpen).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return open.isEmpty ? null : open.first;
  }
}

final leadWorkspaceProvider =
    FutureProvider.family<LeadWorkspace, String>((ref, leadId) async {
  ref.watch(dataRevisionProvider);

  final leadRepo = ref.read(leadRepositoryProvider);
  final lead = await leadRepo.getLeadById(leadId);

  final results = await Future.wait([
    ref.read(callLogRepositoryProvider).getByLead(leadId),
    leadRepo.getRemarks(leadId),
    ref.read(followUpRepositoryProvider).getByLead(leadId),
    ref.read(activityRepositoryProvider).getForLead(leadId),
  ]);

  UserModel? employee;
  if (lead.assignedEmployeeId != null) {
    try {
      employee = await ref
          .read(userRepositoryProvider)
          .getUserById(lead.assignedEmployeeId!);
    } on Exception {
      // A missing assignee is not fatal; the screen just omits that section.
      employee = null;
    }
  }

  return LeadWorkspace(
    lead: lead,
    calls: results[0] as List<CallLogModel>,
    remarks: results[1] as List<RemarkModel>,
    followUps: results[2] as List<FollowUpModel>,
    activities: results[3] as List<ActivityModel>,
    assignedEmployee: employee,
  );
});

/// Write actions available from a lead workspace.
class LeadActions {
  const LeadActions(this._ref);

  final Ref _ref;

  String get _userId {
    final user = _ref.read(authProvider);
    if (user == null) {
      throw StateError('Lead actions require a signed-in user.');
    }
    return user.id;
  }

  /// Opens the platform dialer. Returns false when no dialer is available.
  Future<bool> dial(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s'), ''));
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri);
  }

  Future<void> logCall({
    required String leadId,
    required CallOutcome outcome,
    String? remark,
    DateTime? followUpDate,
  }) async {
    await _ref.read(callLogRepositoryProvider).logCall(
          leadId: leadId,
          employeeId: _userId,
          outcome: outcome,
          remark: remark,
          followUpDate: followUpDate,
        );
    _ref.bumpDataRevision();
  }

  Future<void> addRemark(String leadId, String text) async {
    await _ref.read(leadRepositoryProvider).addRemark(
          leadId: leadId,
          authorId: _userId,
          text: text,
        );
    _ref.bumpDataRevision();
  }

  Future<void> updateStatus(String leadId, LeadStatus status) async {
    await _ref
        .read(leadRepositoryProvider)
        .updateStatus(leadId, status, _userId);
    _ref.bumpDataRevision();
  }

  Future<void> updatePriority(String leadId, LeadPriority priority) async {
    await _ref
        .read(leadRepositoryProvider)
        .updatePriority(leadId, priority, _userId);
    _ref.bumpDataRevision();
  }

  Future<void> scheduleFollowUp({
    required String leadId,
    required DateTime scheduledAt,
    String? remark,
  }) async {
    await _ref.read(followUpRepositoryProvider).schedule(
          leadId: leadId,
          employeeId: _userId,
          scheduledAt: scheduledAt,
          remark: remark,
        );
    _ref.bumpDataRevision();
  }
}

final leadActionsProvider = Provider<LeadActions>(LeadActions.new);
