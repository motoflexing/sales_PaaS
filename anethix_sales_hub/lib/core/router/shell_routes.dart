import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/enums.dart';
import 'route_names.dart';

class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

/// Bottom-nav destinations per role, in tab order.
const Map<UserRole, List<NavItem>> shellDestinations = {
  UserRole.employee: [
    NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      route: Routes.employeeHome,
    ),
    NavItem(
      label: 'Board',
      icon: Icons.podcasts_outlined,
      selectedIcon: Icons.podcasts_rounded,
      route: Routes.employeeLiveLeads,
    ),
    NavItem(
      label: 'My Leads',
      icon: Icons.folder_shared_outlined,
      selectedIcon: Icons.folder_shared_rounded,
      route: Routes.employeeMyLeads,
    ),
    NavItem(
      label: 'Followup',
      icon: Icons.event_repeat_outlined,
      selectedIcon: Icons.event_repeat_rounded,
      route: Routes.employeeFollowUps,
    ),
    NavItem(
      label: 'Ranking',
      icon: Icons.leaderboard_outlined,
      selectedIcon: Icons.leaderboard_rounded,
      route: Routes.employeeLeaderboard,
    ),
  ],
  UserRole.manager: [
    NavItem(
      label: 'Home',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      route: Routes.managerDashboard,
    ),
    NavItem(
      label: 'Leads',
      icon: Icons.workspaces_outline,
      selectedIcon: Icons.workspaces_rounded,
      route: Routes.managerLeads,
    ),
    NavItem(
      label: 'Team',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      route: Routes.managerTeam,
    ),
    NavItem(
      label: 'Followup',
      icon: Icons.event_repeat_outlined,
      selectedIcon: Icons.event_repeat_rounded,
      route: Routes.managerFollowUps,
    ),
    NavItem(
      label: 'Ranking',
      icon: Icons.leaderboard_outlined,
      selectedIcon: Icons.leaderboard_rounded,
      route: Routes.managerLeaderboard,
    ),
  ],
  UserRole.admin: [
    NavItem(
      label: 'Home',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      route: Routes.adminDashboard,
    ),
    NavItem(
      label: 'Users',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      route: Routes.adminUsers,
    ),
    NavItem(
      label: 'Leads',
      icon: Icons.workspaces_outline,
      selectedIcon: Icons.workspaces_rounded,
      route: Routes.adminLeads,
    ),
    NavItem(
      label: 'Attendance',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check_rounded,
      route: Routes.adminAttendance,
    ),
    NavItem(
      label: 'Reports',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      route: Routes.adminReports,
    ),
  ],
};

/// Scaffold shared by every tab of a role's shell.
class RoleShell extends StatelessWidget {
  const RoleShell({super.key, required this.role, required this.child});

  final UserRole role;
  final Widget child;

  int _selectedIndex(BuildContext context, List<NavItem> items) {
    final location = GoRouterState.of(context).uri.path;
    var best = 0;
    var bestLength = -1;
    for (var i = 0; i < items.length; i++) {
      final route = items[i].route;
      final matches = location == route ||
          (route != Routes.prefixFor(role) && location.startsWith('$route/'));
      if (matches && route.length > bestLength) {
        best = i;
        bestLength = route.length;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final items = shellDestinations[role]!;
    final index = _selectedIndex(context, items);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          if (i == index) return;
          context.go(items[i].route);
        },
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
              tooltip: item.label,
            ),
        ],
      ),
    );
  }
}
