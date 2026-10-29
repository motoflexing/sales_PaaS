import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/screens/admin_attendance_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/admin_leads_screen.dart';
import '../../features/admin/screens/admin_reports_screen.dart';
import '../../features/admin/screens/create_user_screen.dart';
import '../../features/admin/screens/user_detail_screen.dart';
import '../../features/admin/screens/user_list_screen.dart';
import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/employee/screens/employee_home_screen.dart';
import '../../features/employee/screens/follow_ups_screen.dart';
import '../../features/employee/screens/lead_work_screen.dart';
import '../../features/employee/screens/live_leads_screen.dart';
import '../../features/employee/screens/my_leads_screen.dart';
import '../../features/leaderboard/screens/leaderboard_screen.dart';
import '../../features/manager/screens/create_lead_screen.dart';
import '../../features/manager/screens/employee_performance_screen.dart';
import '../../features/manager/screens/import_leads_screen.dart';
import '../../features/manager/screens/lead_detail_screen.dart';
import '../../features/manager/screens/manager_dashboard_screen.dart';
import '../../features/manager/screens/manager_follow_ups_screen.dart';
import '../../features/manager/screens/manager_leads_screen.dart';
import '../../features/manager/screens/team_screen.dart';
import '../../shared/models/enums.dart';
import '../widgets/loading_state.dart';
import 'route_names.dart';
import 'shell_routes.dart';

/// Bridges Riverpod's auth state to GoRouter, which wants a [Listenable].
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

/// The root navigator, exposed so services outside the widget tree — the FCM
/// handler, notably — can navigate without a BuildContext of their own.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Messenger for SnackBars raised from outside a screen, such as a push that
/// arrives while the app is in the foreground.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final notifier = ref.read(authProvider.notifier);
      final user = ref.read(authProvider);
      final location = state.matchedLocation;

      // Hold on the splash until the persisted session has been read.
      if (notifier.isBootstrapping) {
        return location == Routes.splash ? null : Routes.splash;
      }

      final isAuthRoute = location == Routes.login ||
          location == Routes.forgotPassword ||
          location == Routes.splash;

      if (user == null) {
        return isAuthRoute && location != Routes.splash ? null : Routes.login;
      }

      final home = Routes.homeFor(user.role);
      if (isAuthRoute) return home;

      // Keep each role inside its own section of the app.
      if (!location.startsWith(Routes.prefixFor(user.role))) return home;

      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const _SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      // ---------------- Employee ----------------
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (_, __, child) =>
            RoleShell(role: UserRole.employee, child: child),
        routes: [
          GoRoute(
            path: Routes.employeeHome,
            builder: (_, __) => const EmployeeHomeScreen(),
          ),
          GoRoute(
            path: Routes.employeeLiveLeads,
            builder: (_, __) => const LiveLeadsScreen(),
          ),
          GoRoute(
            path: Routes.employeeMyLeads,
            builder: (_, __) => const MyLeadsScreen(),
          ),
          GoRoute(
            path: Routes.employeeFollowUps,
            builder: (_, __) => const FollowUpsScreen(),
          ),
          GoRoute(
            path: Routes.employeeLeaderboard,
            builder: (_, __) => const LeaderboardScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '${Routes.employeeMyLeads}/:leadId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            LeadWorkScreen(leadId: state.pathParameters['leadId']!),
      ),
      GoRoute(
        path: Routes.employeeAttendance,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const AttendanceScreen(),
      ),

      // ---------------- Manager ----------------
      ShellRoute(
        builder: (_, __, child) =>
            RoleShell(role: UserRole.manager, child: child),
        routes: [
          GoRoute(
            path: Routes.managerDashboard,
            builder: (_, __) => const ManagerDashboardScreen(),
          ),
          GoRoute(
            path: Routes.managerLeads,
            builder: (_, __) => const ManagerLeadsScreen(),
          ),
          GoRoute(
            path: Routes.managerTeam,
            builder: (_, __) => const TeamScreen(),
          ),
          GoRoute(
            path: Routes.managerFollowUps,
            builder: (_, __) => const ManagerFollowUpsScreen(),
          ),
          GoRoute(
            path: Routes.managerLeaderboard,
            builder: (_, __) => const LeaderboardScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.managerCreateLead,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const CreateLeadScreen(),
      ),
      GoRoute(
        path: Routes.managerImportLeads,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const ImportLeadsScreen(),
      ),
      GoRoute(
        path: '${Routes.managerLeads}/:leadId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            LeadDetailScreen(leadId: state.pathParameters['leadId']!),
      ),
      GoRoute(
        path: '${Routes.managerTeam}/:employeeId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => EmployeePerformanceScreen(
          employeeId: state.pathParameters['employeeId']!,
        ),
      ),

      // ---------------- Admin ----------------
      ShellRoute(
        builder: (_, __, child) =>
            RoleShell(role: UserRole.admin, child: child),
        routes: [
          GoRoute(
            path: Routes.adminDashboard,
            builder: (_, __) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: Routes.adminUsers,
            builder: (_, __) => const UserListScreen(),
          ),
          GoRoute(
            path: Routes.adminLeads,
            builder: (_, __) => const AdminLeadsScreen(),
          ),
          GoRoute(
            path: Routes.adminAttendance,
            builder: (_, __) => const AdminAttendanceScreen(),
          ),
          GoRoute(
            path: Routes.adminReports,
            builder: (_, __) => const AdminReportsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.adminCreateUser,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const CreateUserScreen(),
      ),
      GoRoute(
        path: Routes.adminLeaderboard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const LeaderboardScreen(showAppBarBack: true),
      ),
      GoRoute(
        path: '${Routes.adminUsers}/:userId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            UserDetailScreen(userId: state.pathParameters['userId']!),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_rounded, size: 56),
              const SizedBox(height: 16),
              Text(
                'We could not find "${state.uri}".',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final user = ref.read(authProvider);
                  context.go(
                    user == null ? Routes.login : Routes.homeFor(user.role),
                  );
                },
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.insights_rounded,
                size: 40,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Anethix Sales Hub',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            const InlineSpinner(size: 22),
          ],
        ),
      ),
    );
  }
}
