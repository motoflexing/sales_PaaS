import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical Firestore collection names. Every repository goes through here so
/// a rename is a one-line change and the security rules stay in sync.
class Collections {
  const Collections._();

  static const String users = 'users';
  static const String leads = 'leads';
  static const String callLogs = 'callLogs';
  static const String followUps = 'followUps';
  static const String attendance = 'attendance';
  static const String activities = 'activities';
  static const String remarks = 'remarks';
  static const String leaderboard = 'leaderboard';
}

/// Thin accessors so repositories never spell a collection path by hand.
extension FirestoreCollections on FirebaseFirestore {
  CollectionReference<Map<String, dynamic>> get usersRef =>
      collection(Collections.users);
  CollectionReference<Map<String, dynamic>> get leadsRef =>
      collection(Collections.leads);
  CollectionReference<Map<String, dynamic>> get callLogsRef =>
      collection(Collections.callLogs);
  CollectionReference<Map<String, dynamic>> get followUpsRef =>
      collection(Collections.followUps);
  CollectionReference<Map<String, dynamic>> get attendanceRef =>
      collection(Collections.attendance);
  CollectionReference<Map<String, dynamic>> get activitiesRef =>
      collection(Collections.activities);
  CollectionReference<Map<String, dynamic>> get remarksRef =>
      collection(Collections.remarks);
  CollectionReference<Map<String, dynamic>> get leaderboardRef =>
      collection(Collections.leaderboard);
}
