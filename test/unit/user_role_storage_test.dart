// test/unit/user_role_storage_test.dart
//
// Unit tests for UserRoleStorage — role persistence, cache, and
// pending-role flow (used during Google Sign-In).
//
// Run: flutter test test/unit/user_role_storage_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bookmyeventnow/user_role_storage.dart';

void main() {
  setUp(() {
    // Reset SharedPreferences to a clean state before each test
    SharedPreferences.setMockInitialValues({});
    // Clear the in-memory cache by resetting the singleton state
    UserRoleStorage.instance.setPendingRole(null);
  });

  group('appRoleFromStorage()', () {
    test('returns AppRole.user for "user"', () {
      expect(appRoleFromStorage('user'), AppRole.user);
    });

    test('returns AppRole.vendor for "vendor"', () {
      expect(appRoleFromStorage('vendor'), AppRole.vendor);
    });

    test('returns null for unknown string', () {
      expect(appRoleFromStorage('admin'), isNull);
    });

    test('returns null for null input', () {
      expect(appRoleFromStorage(null), isNull);
    });
  });

  group('AppRoleDisplay extension', () {
    test('label returns "User" for user role', () {
      expect(AppRole.user.label, 'User');
    });

    test('label returns "Vendor" for vendor role', () {
      expect(AppRole.vendor.label, 'Vendor');
    });

    test('storageValue matches enum name', () {
      expect(AppRole.user.storageValue, 'user');
      expect(AppRole.vendor.storageValue, 'vendor');
    });
  });

  group('UserRoleStorage.saveRole and loadRole', () {
    test('saves and loads user role from SharedPreferences', () async {
      await UserRoleStorage.instance.saveRole('uid-001', AppRole.user);
      // Clear memory cache to force load from prefs
      final loaded = await UserRoleStorage.instance.loadRole('uid-001');
      expect(loaded, AppRole.user);
    });

    test('saves and loads vendor role from SharedPreferences', () async {
      await UserRoleStorage.instance.saveRole('uid-002', AppRole.vendor);
      final loaded = await UserRoleStorage.instance.loadRole('uid-002');
      expect(loaded, AppRole.vendor);
    });

    test('returns null for UID with no saved role', () async {
      final loaded = await UserRoleStorage.instance.loadRole('uid-no-role');
      expect(loaded, isNull);
    });
  });

  group('UserRoleStorage - pending role flow (sign-in)', () {
    test('setPendingRole stores role that is picked up on first loadRole', () async {
      UserRoleStorage.instance.setPendingRole(AppRole.vendor);
      final loaded = await UserRoleStorage.instance.loadRole('uid-new');
      expect(loaded, AppRole.vendor);
    });

    test('pending role is consumed after first loadRole', () async {
      UserRoleStorage.instance.setPendingRole(AppRole.user);
      await UserRoleStorage.instance.loadRole('uid-consume');
      // Second load should return null (pending was already taken)
      final secondLoad = await UserRoleStorage.instance.loadRole('uid-consume-2');
      expect(secondLoad, isNull);
    });

    test('setPendingRole with null clears pending role', () async {
      UserRoleStorage.instance.setPendingRole(AppRole.vendor);
      UserRoleStorage.instance.setPendingRole(null);
      final loaded = await UserRoleStorage.instance.loadRole('uid-cleared');
      expect(loaded, isNull);
    });

    test('saveRole clears pending role', () async {
      UserRoleStorage.instance.setPendingRole(AppRole.vendor);
      await UserRoleStorage.instance.saveRole('uid-save', AppRole.user);
      // After saveRole, pending should be cleared
      final loaded = await UserRoleStorage.instance.loadRole('uid-save-other');
      expect(loaded, isNull);
    });
  });

  group('UserRoleStorage.clearRole', () {
    test('clearRole removes role from cache and SharedPreferences', () async {
      await UserRoleStorage.instance.saveRole('uid-clear', AppRole.user);
      await UserRoleStorage.instance.clearRole('uid-clear');
      final loaded = await UserRoleStorage.instance.loadRole('uid-clear');
      expect(loaded, isNull);
    });
  });
}
