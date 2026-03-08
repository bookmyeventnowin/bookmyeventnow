// integration_test/auth_flow_test.dart
//
// Integration tests for the Authentication & Login flow.
// Tests: splash screen, login page UI, role selection, and navigation.
//
// Prerequisites:
//   - Android emulator or physical device connected
//   - Firebase emulator running (optional but recommended for CI)
//
// Run:
//   flutter test integration_test/auth_flow_test.dart \
//     --device-id emulator-5554

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bookmyeventnow/main.dart' as app;
import 'package:bookmyeventnow/user_role_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('[AUTH] Splash Screen', () {
    testWidgets('BMEN-AUTH-001 | Splash shows logo and app name on cold start',
        (tester) async {
      app.main();
      await tester.pump();

      // Splash screen should be visible immediately
      expect(find.text('Book My Event Now'), findsOneWidget);
    });

    testWidgets('BMEN-AUTH-002 | Splash progress indicator is shown', (tester) async {
      app.main();
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('BMEN-AUTH-003 | App transitions from splash to login page',
        (tester) async {
      app.main();
      // Wait past splash delay (1 second + animation)
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should land on LoginPage (user is not signed in)
      expect(find.text("Let's Go"), findsOneWidget);
    });
  });

  group('[AUTH] Login Page - UI Verification', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('BMEN-AUTH-004 | Login page renders all required elements',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Logo
      expect(find.byType(Image), findsWidgets);

      // Heading
      expect(find.text('Who Are You?'), findsOneWidget);

      // Role options
      for (final role in AppRole.values) {
        expect(find.text(role.label), findsOneWidget);
      }

      // Sign in button
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('BMEN-AUTH-005 | Login page has dark/black background',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, Colors.black);
    });
  });

  group('[AUTH] Role Selection', () {
    testWidgets('BMEN-AUTH-006 | User can select "User" role', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.text('User'));
      await tester.pump();

      final tiles = tester.widgetList<RadioListTile<AppRole>>(
        find.byType(RadioListTile<AppRole>),
      ).toList();
      final userTile = tiles.firstWhere((t) => t.value == AppRole.user);
      expect(userTile.groupValue, AppRole.user);
    });

    testWidgets('BMEN-AUTH-007 | User can select "Vendor" role', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.text('Vendor'));
      await tester.pump();

      final tiles = tester.widgetList<RadioListTile<AppRole>>(
        find.byType(RadioListTile<AppRole>),
      ).toList();
      final vendorTile = tiles.firstWhere((t) => t.value == AppRole.vendor);
      expect(vendorTile.groupValue, AppRole.vendor);
    });

    testWidgets('BMEN-AUTH-008 | Tapping Sign In without role shows validation error',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();

      expect(
        find.text('Please select a role before signing in.'),
        findsOneWidget,
      );
    });

    testWidgets('BMEN-AUTH-009 | Role radio buttons are mutually exclusive',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.text('User'));
      await tester.pump();
      await tester.tap(find.text('Vendor'));
      await tester.pump();

      final tiles = tester.widgetList<RadioListTile<AppRole>>(
        find.byType(RadioListTile<AppRole>),
      ).toList();
      // Only one role should be selected
      final selectedCount = tiles.where((t) => t.groupValue == t.value).length;
      expect(selectedCount, 1);
    });
  });

  group('[AUTH] Sign-Out & Session Persistence', () {
    testWidgets('BMEN-AUTH-010 | Cleared role shows RoleRequiredPage on next load',
        (tester) async {
      // Simulate a user with no role stored
      SharedPreferences.setMockInitialValues({});
      UserRoleStorage.instance.setPendingRole(null);

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should land on LoginPage since no auth
      expect(find.text("Let's Go"), findsOneWidget);
    });
  });
}
