import 'package:anethix_sales_hub/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Walks every route in the app and fails on any render error - overflows
/// included, since those surface as exceptions in a test binding.
Future<void> _boot(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(const ProviderScope(child: AnethixSalesHubApp()));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _signIn(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.tap(find.widgetWithText(FilledButton, 'Login'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

/// Drags the page up in steps so lazily-built content below the fold is
/// actually laid out - that is where overflow errors hide.
Future<void> _scrollThrough(WidgetTester tester, {int steps = 6}) async {
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) return;

  for (var i = 0; i < steps; i++) {
    await tester.drag(scrollable.first, const Offset(0, -400));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    if (tester.takeException() case final error?) {
      fail('scrolling threw: $error');
    }
  }
}

Future<void> _visit(
  WidgetTester tester,
  String route, {
  bool scroll = true,
}) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(route);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  expect(
    tester.takeException(),
    isNull,
    reason: 'rendering $route threw',
  );
  if (scroll) await _scrollThrough(tester);
}

/// Several screens nest scrollables (a horizontal pipeline stepper inside a
/// vertical page), so the outer page list is addressed explicitly rather than
/// letting the finder guess - and it stays valid as inner ones scroll away.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

// NOTE: skipped by the Firebase migration.
//
// These tests boot the real app and sign in with the mock credential table.
// The app now calls `Firebase.initializeApp` on launch and every repository
// talks to Firestore, so a plain `flutter test` has no backend to answer them.
// Reviving them needs either the Firestore emulator or a fake injected through
// `firestoreProvider`/`firebaseAuthProvider` (both are overridable providers in
// lib/shared/providers/shared_providers.dart) plus seeded documents.
const String _skipReason =
    'Needs a Firestore fake or the emulator after the Firebase migration.';

void main() {
  group('screen render', () {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('every employee screen renders cleanly', (tester) async {
    await _boot(tester);
    await _signIn(tester, 'priya@anethix.com', 'emp123');

    for (final route in const [
      '/employee',
      '/employee/live-leads',
      '/employee/my-leads',
      '/employee/follow-ups',
      '/employee/leaderboard',
      '/employee/attendance',
    ]) {
      await _visit(tester, route);
    }
  });

  testWidgets('the lead workspace renders for a claimed lead', (tester) async {
    await _boot(tester);
    await _signIn(tester, 'priya@anethix.com', 'emp123');

    await _visit(tester, '/employee/my-leads');
    // Open the first lead the employee owns.
    final firstCard = find.byType(Card).first;
    await tester.tap(firstCard);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(tester.takeException(), isNull);
    expect(find.text('Lead workspace'), findsOneWidget);

    await _scrollTo(tester, find.text('CALL'));
    expect(find.text('CALL'), findsOneWidget);

    await _scrollTo(tester, find.text('Activity timeline'));
    expect(find.text('Activity timeline'), findsOneWidget);
  });

  testWidgets('every manager screen renders cleanly', (tester) async {
    await _boot(tester);
    await _signIn(tester, 'manager1@anethix.com', 'manager123');

    for (final route in const [
      '/manager',
      '/manager/leads',
      '/manager/team',
      '/manager/follow-ups',
      '/manager/leaderboard',
      '/manager/leads/create',
      '/manager/leads/import',
    ]) {
      await _visit(tester, route);
    }
  });

  testWidgets('manager drill-downs render cleanly', (tester) async {
    await _boot(tester);
    await _signIn(tester, 'manager1@anethix.com', 'manager123');

    await _visit(tester, '/manager/team/u_emp_1');
    expect(find.text('Performance'), findsOneWidget);

    await _visit(tester, '/manager/leads/lead_020');
    expect(find.text('Lead detail'), findsOneWidget);

    await _scrollTo(tester, find.text('Call history'));
    expect(find.text('Call history'), findsOneWidget);
  });

  testWidgets('every admin screen renders cleanly', (tester) async {
    await _boot(tester);
    await _signIn(tester, 'admin@anethix.com', 'admin123');

    for (final route in const [
      '/admin',
      '/admin/users',
      '/admin/leads',
      '/admin/attendance',
      '/admin/reports',
      '/admin/leaderboard',
      '/admin/users/create',
      '/admin/users/u_emp_1',
      '/admin/users/u_mgr_1',
    ]) {
      await _visit(tester, route);
    }
  });

  testWidgets('a role cannot reach another role\'s section', (tester) async {
    await _boot(tester);
    await _signIn(tester, 'priya@anethix.com', 'emp123');

    // The guard bounces an employee back to their own home.
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).go('/admin/users');
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Live Leads'), findsWidgets);
    expect(find.text('Users'), findsNothing);
  });

  testWidgets('the manager draft tab supports selecting and publishing',
      (tester) async {
    await _boot(tester);
    await _signIn(tester, 'manager1@anethix.com', 'manager123');
    await _visit(tester, '/manager/leads', scroll: false);

    // The Draft tab is first and seeded with unpublished leads.
    final checkbox = find.byType(Checkbox).first;
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(find.text('MAKE LIVE'), findsOneWidget);
    expect(find.textContaining('selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  }, skip: _skipReason);
}
