import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/lead_status.dart';
import '../../shared/models/enums.dart';
import '../firebase/activity_logger.dart';
import '../firebase/firestore_mappers.dart';
import '../firebase/firestore_refs.dart';
import '../models/activity_model.dart';
import '../models/import_summary.dart';
import '../models/lead_model.dart';
import '../models/remark_model.dart';

class LeadAlreadyClaimedException implements Exception {
  const LeadAlreadyClaimedException([
    this.message = 'This lead has already been claimed.',
  ]);
  final String message;
  @override
  String toString() => message;
}

class LeadRepositoryException implements Exception {
  const LeadRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Leads in Firestore. The live board and an employee's own list are exposed
/// both as one-shot futures (for the existing pull-to-refresh paths) and as
/// `snapshots()` streams, so a lead claimed by one rep disappears from every
/// other rep's board without anyone refreshing.
class LeadRepository {
  LeadRepository({FirebaseFirestore? firestore, ActivityLogger? activityLogger})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _activity =
          activityLogger ??
          ActivityLogger(firestore ?? FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final ActivityLogger _activity;

  // ------------------------------- Reads -------------------------------

  Future<List<LeadModel>> getAllLeads() async {
    final snapshot = await _guard(() => _firestore.leadsRef.get());
    return _sorted(mapDocs(snapshot, leadFromDoc));
  }

  /// Leads a manager owns: ones they created, plus ones they published. Two
  /// fields means an `or` filter; results are merged and de-duplicated by id.
  Future<List<LeadModel>> getLeadsByManager(String managerId) async {
    final snapshot = await _guard(
      () => _firestore.leadsRef
          .where(
            Filter.or(
              Filter('createdBy', isEqualTo: managerId),
              Filter('publishedBy', isEqualTo: managerId),
            ),
          )
          .get(),
    );
    return _sorted(mapDocs(snapshot, leadFromDoc));
  }

  Future<List<LeadModel>> getLiveLeads() async {
    final snapshot = await _guard(() => _liveLeadsQuery().get());
    return _sorted(mapDocs(snapshot, leadFromDoc));
  }

  Future<List<LeadModel>> getLeadsByEmployee(String employeeId) async {
    final snapshot = await _guard(
      () => _firestore.leadsRef
          .where('assignedEmployeeId', isEqualTo: employeeId)
          .get(),
    );
    return _sorted(mapDocs(snapshot, leadFromDoc));
  }

  Future<LeadModel> getLeadById(String leadId) async {
    final doc = await _guard(() => _firestore.leadsRef.doc(leadId).get());
    if (!doc.exists) {
      throw const LeadRepositoryException('That lead no longer exists.');
    }
    return leadFromDoc(doc);
  }

  // ------------------------- Real-time streams -------------------------

  /// The unclaimed live board, newest publication first.
  Stream<List<LeadModel>> watchLiveLeads() {
    return _liveLeadsQuery()
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((snapshot) => _sorted(mapDocs(snapshot, leadFromDoc)));
  }

  Stream<List<LeadModel>> watchLeadsByEmployee(String employeeId) {
    return _firestore.leadsRef
        .where('assignedEmployeeId', isEqualTo: employeeId)
        .snapshots()
        .map((snapshot) => _sorted(mapDocs(snapshot, leadFromDoc)));
  }

  Stream<LeadModel?> watchLead(String leadId) {
    return _firestore.leadsRef
        .doc(leadId)
        .snapshots()
        .map((doc) => doc.exists ? leadFromDoc(doc) : null);
  }

  Query<Map<String, dynamic>> _liveLeadsQuery() => _firestore.leadsRef
      .where('status', isEqualTo: LeadStatus.live.name)
      .where('assignedEmployeeId', isNull: true);

  // ------------------------------- Writes -------------------------------

  Future<LeadModel> createLead({
    required String name,
    required String phone,
    required LeadPriority priority,
    required String createdBy,
    String? company,
    String? contactPerson,
    String? email,
    String? location,
    String? industry,
    String? source,
    String? leadType,
    String? alternatePhone,
    String? managerRemark,
    LeadStatus status = LeadStatus.draft,
  }) async {
    final now = DateTime.now();
    final doc = _firestore.leadsRef.doc();
    final lead = LeadModel(
      id: doc.id,
      name: name.trim(),
      company: _blankToNull(company),
      contactPerson: _blankToNull(contactPerson),
      phone: phone.trim(),
      alternatePhone: _blankToNull(alternatePhone),
      email: _blankToNull(email),
      location: _blankToNull(location),
      industry: _blankToNull(industry),
      source: _blankToNull(source),
      leadType: _blankToNull(leadType),
      priority: priority,
      status: status,
      managerRemark: _blankToNull(managerRemark),
      publishedBy: status == LeadStatus.live ? createdBy : null,
      publishedAt: status == LeadStatus.live ? now : null,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
      lastActivityAt: now,
    );

    await _guard(() => doc.set(lead.toMap()));

    await _activity.log(
      userId: createdBy,
      leadId: lead.id,
      action: ActivityAction.leadCreated,
      description: 'Created lead "${lead.displayTitle}"',
      at: now,
    );

    if (lead.managerRemark != null) {
      final authorName = await _activity.nameOf(createdBy);
      await _guard(
        () => _firestore.remarksRef.add(
          RemarkModel(
            id: '_',
            leadId: lead.id,
            authorId: createdBy,
            authorName: authorName,
            text: lead.managerRemark!,
            createdAt: now,
          ).toMap(),
        ),
      );
    }
    return lead;
  }

  Future<LeadModel> updateLead(LeadModel lead) async {
    final updated = lead.copyWith(updatedAt: DateTime.now());
    await _guard(
      () => _firestore.leadsRef
          .doc(lead.id)
          .set(updated.toMap(), SetOptions(merge: true)),
    );
    return updated;
  }

  /// Publishes drafts to the live board so employees can claim them. One batch,
  /// so a partial publish can never leave half the selection stranded.
  Future<int> publishLeads(List<String> leadIds, String managerId) async {
    if (leadIds.isEmpty) {
      throw const LeadRepositoryException(
        'None of the selected leads could be published.',
      );
    }

    final now = DateTime.now();
    final batch = _firestore.batch();
    var published = 0;

    for (final id in leadIds) {
      final doc = await _guard(() => _firestore.leadsRef.doc(id).get());
      if (!doc.exists) continue;
      if (leadFromDoc(doc).status != LeadStatus.draft) continue;

      batch.update(doc.reference, {
        'status': LeadStatus.live.name,
        'publishedBy': managerId,
        // Server time is what the live board orders by, so it must not depend
        // on the publishing device's clock.
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
      await _activity.logInBatch(
        batch,
        userId: managerId,
        leadId: id,
        action: ActivityAction.leadPublished,
        description: 'Published the lead to the live board',
        at: now,
      );
      published++;
    }

    if (published == 0) {
      throw const LeadRepositoryException(
        'None of the selected leads could be published.',
      );
    }

    await _guard(batch.commit);
    return published;
  }

  /// Alias for [publishLeads] under the backend contract's name. The publishing
  /// manager is resolved from each lead's creator.
  Future<int> makeLeadsLive(List<String> leadIds, String managerId) =>
      publishLeads(leadIds, managerId);

  /// Hands leads straight to one employee, skipping the live board entirely.
  /// This is the direct-assignment counterpart to [publishLeads]: the lead goes
  /// from draft (or live-and-unclaimed) to `claimed` in a single batch, so a
  /// half-finished assignment can never leave part of the selection stranded.
  ///
  /// Leads that are already held by somebody are skipped rather than
  /// reassigned — a direct assignment must never take a lead off the rep who
  /// is already working it.
  Future<void> assignLeadsToEmployee({
    required List<String> leadIds,
    required String employeeId,
    required String managerId,
  }) async {
    if (leadIds.isEmpty) {
      throw const LeadRepositoryException(
        'None of the selected leads could be assigned.',
      );
    }

    final now = DateTime.now();
    final employeeName = await _activity.nameOf(employeeId);
    final managerName = await _activity.nameOf(managerId);
    final batch = _firestore.batch();
    var assigned = 0;

    for (final id in leadIds) {
      final doc = await _guard(() => _firestore.leadsRef.doc(id).get());
      if (!doc.exists) continue;

      final lead = leadFromDoc(doc);
      final isAssignable =
          lead.assignedEmployeeId == null &&
          (lead.status == LeadStatus.draft || lead.status == LeadStatus.live);
      if (!isAssignable) continue;

      batch.update(doc.reference, {
        'status': LeadStatus.claimed.name,
        'assignedEmployeeId': employeeId,
        // Server time throughout: a direct assignment is also a publication,
        // and the boards order by these fields.
        'claimedAt': FieldValue.serverTimestamp(),
        'publishedBy': managerId,
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
      await _activity.logInBatch(
        batch,
        userId: managerId,
        leadId: id,
        action: ActivityAction.leadClaimed,
        description: 'Lead assigned to $employeeName by $managerName',
        at: now,
      );
      assigned++;
    }

    if (assigned == 0) {
      throw const LeadRepositoryException(
        'None of the selected leads could be assigned.',
      );
    }

    await _guard(batch.commit);
  }

  /// Claims a live lead for an employee inside a transaction: re-read the
  /// document, verify it is still live and unassigned, then write. Two reps
  /// tapping the same card at the same moment means exactly one of them wins
  /// and the other gets [LeadAlreadyClaimedException].
  Future<LeadModel> claimLead(String leadId, String employeeId) async {
    final now = DateTime.now();
    final ref = _firestore.leadsRef.doc(leadId);

    final LeadModel claimed;
    try {
      claimed = await _firestore.runTransaction<LeadModel>((transaction) async {
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) {
          throw const LeadRepositoryException('That lead no longer exists.');
        }

        final lead = leadFromDoc(snapshot);
        if (lead.status != LeadStatus.live || lead.assignedEmployeeId != null) {
          throw const LeadAlreadyClaimedException();
        }

        final result = lead.copyWith(
          status: LeadStatus.claimed,
          assignedEmployeeId: employeeId,
          claimedAt: now,
          updatedAt: now,
          lastActivityAt: now,
        );
        transaction.update(ref, {
          'status': LeadStatus.claimed.name,
          'assignedEmployeeId': employeeId,
          'claimedAt': writeTimestamp(now),
          'updatedAt': writeTimestamp(now),
          'lastActivityAt': writeTimestamp(now),
        });
        return result;
      });
    } on LeadAlreadyClaimedException {
      rethrow;
    } on LeadRepositoryException {
      rethrow;
    } on FirebaseException catch (error) {
      // A transaction that keeps losing its retries under contention is, from
      // the rep's point of view, the same thing as losing the race.
      if (error.code == 'aborted' || error.code == 'failed-precondition') {
        throw const LeadAlreadyClaimedException();
      }
      throw LeadRepositoryException(_message(error));
    }

    await _activity.log(
      userId: employeeId,
      leadId: leadId,
      action: ActivityAction.leadClaimed,
      description: 'Claimed the lead',
      at: now,
    );
    return claimed;
  }

  Future<LeadModel> updateStatus(
    String leadId,
    LeadStatus status,
    String userId,
  ) async {
    final lead = await getLeadById(leadId);
    if (!allowedNextStatuses(lead.status).contains(status)) {
      throw LeadRepositoryException(
        'A lead cannot move from ${lead.status.label} to ${status.label}.',
      );
    }

    final now = DateTime.now();
    await _guard(
      () => _firestore.leadsRef.doc(leadId).update({
        'status': status.name,
        'updatedAt': writeTimestamp(now),
        'lastActivityAt': writeTimestamp(now),
      }),
    );
    await _activity.log(
      userId: userId,
      leadId: leadId,
      action: ActivityAction.statusChanged,
      description:
          'Moved the lead from ${lead.status.label} to ${status.label}',
      at: now,
    );
    return lead.copyWith(status: status, updatedAt: now, lastActivityAt: now);
  }

  Future<LeadModel> updatePriority(
    String leadId,
    LeadPriority priority,
    String userId,
  ) async {
    final lead = await getLeadById(leadId);
    final now = DateTime.now();
    await _guard(
      () => _firestore.leadsRef.doc(leadId).update({
        'priority': priority.name,
        'updatedAt': writeTimestamp(now),
        'lastActivityAt': writeTimestamp(now),
      }),
    );
    await _activity.log(
      userId: userId,
      leadId: leadId,
      action: ActivityAction.priorityChanged,
      description:
          'Changed priority from ${lead.priority.label} to ${priority.label}',
      at: now,
    );
    return lead.copyWith(
      priority: priority,
      updatedAt: now,
      lastActivityAt: now,
    );
  }

  // ------------------------------- Remarks -------------------------------

  Future<List<RemarkModel>> getRemarks(String leadId) async {
    final snapshot = await _guard(
      () => _firestore.remarksRef
          .where('leadId', isEqualTo: leadId)
          .orderBy('createdAt', descending: true)
          .get(),
    );
    return mapDocs(snapshot, remarkFromDoc);
  }

  /// Remark timestamps for many leads at once, keyed by lead id.
  ///
  /// One `whereIn` query per 30 leads rather than one query per lead, which is
  /// what keeps the My Leads list from firing an N+1 storm just to decide
  /// whether to draw a badge. Timestamps (not just counts) come back so the
  /// caller can work out how many are newer than the reader's last visit.
  Future<Map<String, List<DateTime>>> getRemarkTimesByLeads(
    List<String> leadIds,
  ) async {
    final ids = leadIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};

    final byLead = <String, List<DateTime>>{};
    for (final chunk in _chunk(ids, 30)) {
      final snapshot = await _guard(
        () => _firestore.remarksRef.where('leadId', whereIn: chunk).get(),
      );
      for (final remark in mapDocs(snapshot, remarkFromDoc)) {
        (byLead[remark.leadId] ??= <DateTime>[]).add(remark.createdAt);
      }
    }
    for (final times in byLead.values) {
      times.sort();
    }
    return byLead;
  }

  /// `whereIn` takes at most 30 values, so longer id lists are split.
  static Iterable<List<T>> _chunk<T>(List<T> source, int size) sync* {
    for (var i = 0; i < source.length; i += size) {
      yield source.sublist(i, min(i + size, source.length));
    }
  }

  Stream<List<RemarkModel>> watchRemarks(String leadId) {
    return _firestore.remarksRef
        .where('leadId', isEqualTo: leadId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => mapDocs(snapshot, remarkFromDoc));
  }

  Future<RemarkModel> addRemark({
    required String leadId,
    required String authorId,
    required String text,
  }) async {
    final now = DateTime.now();
    final doc = _firestore.remarksRef.doc();
    final remark = RemarkModel(
      id: doc.id,
      leadId: leadId,
      authorId: authorId,
      authorName: await _activity.nameOf(authorId),
      text: text.trim(),
      createdAt: now,
    );

    await _guard(() => doc.set(remark.toMap()));
    await _touchLead(leadId, now);
    await _activity.log(
      userId: authorId,
      leadId: leadId,
      action: ActivityAction.remarkAdded,
      description: 'Added a remark',
      at: now,
    );
    return remark;
  }

  /// Bumps the activity clock on a lead. Best-effort: an employee who can write
  /// a remark may not be allowed to write every lead field.
  Future<void> _touchLead(String leadId, DateTime at) async {
    try {
      await _firestore.leadsRef.doc(leadId).update({
        'updatedAt': writeTimestamp(at),
        'lastActivityAt': writeTimestamp(at),
      });
    } on FirebaseException {
      // Not fatal; the record that matters has already been written.
    }
  }

  // -------------------------------- Import --------------------------------

  /// Builds the preview rows for a spreadsheet import.
  ///
  /// The row contents are still synthesised — the picker seam hands this method
  /// a file *name* rather than the file bytes, so there is nothing to parse
  /// yet. What is now real is the duplicate check: phone numbers are matched
  /// against the `leads` collection, so the preview flags rows that would
  /// collide with leads that actually exist.
  Future<List<ParsedLeadRow>> parseImportFile({
    required String fileName,
    required String managerId,
    int rowCount = 24,
  }) async {
    final lower = fileName.toLowerCase();
    if (!lower.endsWith('.csv') &&
        !lower.endsWith('.xlsx') &&
        !lower.endsWith('.xls')) {
      throw const LeadRepositoryException(
        'Unsupported file type. Upload a .csv or .xlsx file.',
      );
    }
    if (rowCount <= 0) {
      throw const LeadRepositoryException(
        'That file has no data rows to import.',
      );
    }

    final rnd = Random(fileName.hashCode);
    final existingPhones = await _existingPhones();
    final rows = <ParsedLeadRow>[];
    final now = DateTime.now();

    const companies = [
      'Sunrise Polymers',
      'Vertex Cloud Services',
      'Ganga Textiles Mills',
      'BlueOak Financial',
      'Medisure Hospitals',
      'Sparsh Education Trust',
      'Urbania Retail',
      'Trikaya Realtors',
      'Neelkanth Chemicals',
      'Fintrail Advisors',
      'Sahara Cold Storage',
      'Bright Path Academy',
    ];
    const contacts = [
      'Rajeev Menon',
      'Swati Kulkarni',
      'Abhishek Ranjan',
      'Divya Prakash',
      'Mohammed Ashraf',
      'Poonam Gupta',
      'Sridhar Balaji',
      'Ritika Malhotra',
    ];
    const cities = [
      'Mumbai',
      'Delhi',
      'Bangalore',
      'Hyderabad',
      'Pune',
      'Chennai',
      'Kolkata',
      'Ahmedabad',
    ];
    const industries = [
      'IT',
      'Manufacturing',
      'Finance',
      'Healthcare',
      'Education',
      'Retail',
      'Real Estate',
    ];

    for (var i = 0; i < rowCount; i++) {
      final company = companies[i % companies.length];
      final contact = contacts[i % contacts.length];
      final city = cities[i % cities.length];

      // ~10% invalid rows (bad phone) and ~5% duplicates of existing leads.
      final roll = rnd.nextInt(100);
      final isInvalid = roll < 10;
      final isDuplicate = !isInvalid && roll < 15;

      final phone = isDuplicate && existingPhones.isNotEmpty
          ? existingPhones.elementAt(i % existingPhones.length)
          : isInvalid
          ? '12${rnd.nextInt(9999)}'
          : '9${(700000000 + rnd.nextInt(99999999)).toString().substring(0, 9)}';

      rows.add(
        ParsedLeadRow(
          rowNumber: i + 2, // row 1 is the header
          isValid: !isInvalid,
          isDuplicate: isDuplicate || existingPhones.contains(phone),
          issue: isInvalid
              ? 'Phone number is not a valid 10-digit Indian mobile'
              : isDuplicate
              ? 'A lead with this phone number already exists'
              : null,
          lead: LeadModel(
            id: 'import_${i + 1}',
            name: '$company enquiry',
            company: company,
            contactPerson: contact,
            phone: phone,
            email:
                '${contact.split(' ').first.toLowerCase()}@${company.split(' ').first.toLowerCase()}.in',
            location: city,
            industry: industries[i % industries.length],
            source: 'Website',
            leadType: i.isEven ? 'SMB' : 'Enterprise',
            priority: LeadPriority.values[i % LeadPriority.values.length],
            status: LeadStatus.draft,
            createdBy: managerId,
            createdAt: now,
            updatedAt: now,
          ),
        ),
      );
    }
    return rows;
  }

  /// Writes the importable rows as drafts. Firestore caps a batch at 500 writes,
  /// so large imports are committed in chunks.
  Future<ImportSummary> importLeads(
    List<ParsedLeadRow> rows,
    String managerId,
  ) async {
    const batchLimit = 400; // leaves headroom for the activity entry
    final now = DateTime.now();
    final importable = rows.where((r) => r.isImportable).toList();

    var imported = 0;
    var batch = _firestore.batch();
    var pending = 0;

    for (final row in importable) {
      final doc = _firestore.leadsRef.doc();
      batch.set(
        doc,
        row.lead
            .copyWith(
              id: doc.id,
              createdBy: managerId,
              createdAt: now,
              updatedAt: now,
              lastActivityAt: now,
            )
            .toMap(),
      );
      imported++;
      pending++;

      if (pending >= batchLimit) {
        await _guard(batch.commit);
        batch = _firestore.batch();
        pending = 0;
      }
    }

    if (pending > 0) {
      await _guard(batch.commit);
    }

    if (imported > 0) {
      await _activity.log(
        userId: managerId,
        action: ActivityAction.leadImported,
        description: 'Imported $imported leads as drafts',
        at: now,
      );
    }

    final duplicate = rows.where((r) => r.isDuplicate && r.isValid).length;
    final invalid = rows.where((r) => !r.isValid).length;
    return ImportSummary(
      total: rows.length,
      imported: imported,
      duplicate: duplicate,
      invalid: invalid,
      skipped: duplicate + invalid,
    );
  }

  Future<Set<String>> _existingPhones() async {
    try {
      final snapshot = await _firestore.leadsRef.get();
      return {
        for (final doc in snapshot.docs)
          if (doc.data()['phone'] is String) doc.data()['phone'] as String,
      };
    } on FirebaseException {
      // Without the existing set we simply cannot flag duplicates; the import
      // preview still works.
      return const <String>{};
    }
  }

  // ------------------------------- Helpers -------------------------------

  static List<LeadModel> _sorted(Iterable<LeadModel> source) {
    final list = source.toList()
      ..sort((a, b) {
        final aAt = a.lastActivityAt ?? a.updatedAt;
        final bAt = b.lastActivityAt ?? b.updatedAt;
        return bAt.compareTo(aAt);
      });
    return List<LeadModel>.unmodifiable(list);
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  static String _message(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'You do not have permission to perform that action.',
      'not-found' => 'That lead no longer exists.',
      'unavailable' || 'network-request-failed' =>
        'No internet connection. Check your network and try again.',
      _ => error.message ?? 'Something went wrong. Please try again.',
    };
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FirebaseException catch (error) {
      throw LeadRepositoryException(_message(error));
    }
  }
}
