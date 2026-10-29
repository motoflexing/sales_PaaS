import '../../shared/models/enums.dart';

class Routes {
  const Routes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';

  // Employee
  static const String employeeHome = '/employee';
  static const String employeeLiveLeads = '/employee/live-leads';
  static const String employeeMyLeads = '/employee/my-leads';
  static const String employeeFollowUps = '/employee/follow-ups';
  static const String employeeLeaderboard = '/employee/leaderboard';
  static const String employeeAttendance = '/employee/attendance';
  static String employeeLead(String leadId) => '/employee/my-leads/$leadId';

  // Manager
  static const String managerDashboard = '/manager';
  static const String managerLeads = '/manager/leads';
  static const String managerCreateLead = '/manager/leads/create';
  static const String managerImportLeads = '/manager/leads/import';
  static const String managerTeam = '/manager/team';
  static const String managerFollowUps = '/manager/follow-ups';
  static const String managerLeaderboard = '/manager/leaderboard';
  static String managerLead(String leadId) => '/manager/leads/$leadId';
  static String managerEmployee(String employeeId) =>
      '/manager/team/$employeeId';

  // Admin
  static const String adminDashboard = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminCreateUser = '/admin/users/create';
  static const String adminLeads = '/admin/leads';
  static const String adminAttendance = '/admin/attendance';
  static const String adminReports = '/admin/reports';
  static const String adminLeaderboard = '/admin/leaderboard';
  static String adminUser(String userId) => '/admin/users/$userId';

  /// Landing route for a role after sign-in.
  static String homeFor(UserRole role) => switch (role) {
        UserRole.admin => adminDashboard,
        UserRole.manager => managerDashboard,
        UserRole.employee => employeeHome,
      };

  /// Route prefix a role is allowed to browse.
  static String prefixFor(UserRole role) => switch (role) {
        UserRole.admin => '/admin',
        UserRole.manager => '/manager',
        UserRole.employee => '/employee',
      };
}
