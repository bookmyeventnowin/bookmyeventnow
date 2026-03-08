// integration_test/all_tests.dart
//
// Master runner — imports all integration test groups so they can be
// executed in one command on a connected device or emulator.
//
// Run ALL integration tests:
//   flutter test integration_test/all_tests.dart --device-id emulator-5554
//
// Run with verbose output:
//   flutter test integration_test/all_tests.dart -v --device-id emulator-5554

import 'package:integration_test/integration_test.dart';

import 'auth_flow_test.dart' as auth;
import 'booking_flow_test.dart' as booking;
import 'vendor_flow_test.dart' as vendor;
import 'playstore_compliance_test.dart' as compliance;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  auth.main();
  booking.main();
  vendor.main();
  compliance.main();
}
