// test/widget/login_page_test.dart
//
// Widget tests for LoginPage — UI rendering, role selection,
// sign-in button state, and error display.
//
// Run: flutter test test/widget/login_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bookmyeventnow/login_page.dart';
import 'package:bookmyeventnow/user_role_storage.dart';

Widget _buildLoginPage() {
  return const MaterialApp(home: LoginPage());
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoginPage - Rendering', () {
    testWidgets('renders AppBar with correct title', (tester) async {
      await tester.pumpWidget(_buildLoginPage());
      expect(find.text("Let's Go"), findsOneWidget);
    });

    testWidgets('renders "Who Are You?" heading', (tester) async {
      await tester.pumpWidget(_buildLoginPage());
      expect(find.text('Who Are You?'), findsOneWidget);
    });

    testWidgets('renders role radio options for all AppRole values', (tester) async {
      await tester.pumpWidget(_buildLoginPage());
      for (final role in AppRole.values) {
        expect(find.text(role.label), findsOneWidget);
      }
    });

    testWidgets('renders "Sign in with Google" button', (tester) async {
      await tester.pumpWidget(_buildLoginPage());
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('renders "Book My Event Now" footer button', (tester) async {
      await tester.pumpWidget(_buildLoginPage());
      expect(find.text('Book My Event Now'), findsOneWidget);
    });

    testWidgets('has black background', (tester) async {
      await tester.pumpWidget(_buildLoginPage());
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.black);
    });
  });

  group('LoginPage - Role Selection', () {
    testWidgets('no role is selected initially', (tester) async {
      await tester.pumpWidget(_buildLoginPage());
      // All radio tiles should be unchecked initially
      final radioTiles = tester.widgetList<RadioListTile<AppRole>>(
        find.byType(RadioListTile<AppRole>),
      ).toList();
      for (final tile in radioTiles) {
        expect(tile.groupValue, isNull);
      }
    });

    testWidgets('selecting User role updates radio selection', (tester) async {
      await tester.pumpWidget(_buildLoginPage());
      await tester.tap(find.text('User'));
      await tester.pump();

      final radioTiles = tester.widgetList<RadioListTile<AppRole>>(
        find.byType(RadioListTile<AppRole>),
      ).toList();
      final userTile = radioTiles.firstWhere((t) => t.value == AppRole.user);
      expect(userTile.groupValue, AppRole.user);
    });

    testWidgets('selecting Vendor role updates radio selection', (tester) async {
      await tester.pumpWidget(_buildLoginPage());
      await tester.tap(find.text('Vendor'));
      await tester.pump();

      final radioTiles = tester.widgetList<RadioListTile<AppRole>>(
        find.byType(RadioListTile<AppRole>),
      ).toList();
      final vendorTile = radioTiles.firstWhere((t) => t.value == AppRole.vendor);
      expect(vendorTile.groupValue, AppRole.vendor);
    });

    testWidgets('switching from User to Vendor updates selection correctly', (tester) async {
      await tester.pumpWidget(_buildLoginPage());

      await tester.tap(find.text('User'));
      await tester.pump();
      await tester.tap(find.text('Vendor'));
      await tester.pump();

      final radioTiles = tester.widgetList<RadioListTile<AppRole>>(
        find.byType(RadioListTile<AppRole>),
      ).toList();
      final vendorTile = radioTiles.firstWhere((t) => t.value == AppRole.vendor);
      expect(vendorTile.groupValue, AppRole.vendor);
    });
  });

  group('LoginPage - Validation', () {
    testWidgets('tapping Sign In without selecting role shows error', (tester) async {
      await tester.pumpWidget(_buildLoginPage());
      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();

      expect(
        find.text('Please select a role before signing in.'),
        findsOneWidget,
      );
    });

    testWidgets('error text is red', (tester) async {
      await tester.pumpWidget(_buildLoginPage());
      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();

      final errorText = tester.widget<Text>(
        find.text('Please select a role before signing in.'),
      );
      expect(errorText.style?.color, Colors.redAccent);
    });

    testWidgets('no error shown on initial render', (tester) async {
      await tester.pumpWidget(_buildLoginPage());
      expect(
        find.text('Please select a role before signing in.'),
        findsNothing,
      );
    });
  });

  group('LoginPage - Footer behaviour', () {
    testWidgets('footer button shows snackbar with info message', (tester) async {
      await tester.pumpWidget(_buildLoginPage());
      await tester.tap(find.text('Book My Event Now'));
      await tester.pump();

      expect(
        find.text('Other login flows can be added.'),
        findsOneWidget,
      );
    });
  });
}
