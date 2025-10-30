import 'package:shared_preferences/shared_preferences.dart';

enum AppRole { user, vendor }

extension AppRoleDisplay on AppRole {
  String get label => switch (this) {
        AppRole.user => 'User',
        AppRole.vendor => 'Vendor',
      };

  String get storageValue => name;
}

AppRole? appRoleFromStorage(String? value) {
  if (value == null) return null;
  for (final role in AppRole.values) {
    if (role.name == value) return role;
  }
  return null;
}

class UserRoleStorage {
  UserRoleStorage._();

  static final UserRoleStorage instance = UserRoleStorage._();

  final Map<String, AppRole> _memoryCache = {};
  AppRole? _pendingRole;

  static String _keyFor(String uid) => 'appRole_$uid';

  void setPendingRole(AppRole? role) {
    _pendingRole = role;
  }

  AppRole? _takePendingRole() {
    final role = _pendingRole;
    _pendingRole = null;
    return role;
  }

  Future<void> saveRole(String uid, AppRole role) async {
    _memoryCache[uid] = role;
    _pendingRole = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(uid), role.storageValue);
  }

  Future<AppRole?> loadRole(String uid) async {
    final cached = _memoryCache[uid];
    if (cached != null) return cached;

    final pending = _takePendingRole();
    if (pending != null) {
      _memoryCache[uid] = pending;
      return pending;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyFor(uid));
    final role = appRoleFromStorage(stored);
    if (role != null) {
      _memoryCache[uid] = role;
    }
    return role;
  }

  Future<void> clearRole(String uid) async {
    _memoryCache.remove(uid);
    if (_pendingRole != null) {
      _pendingRole = null;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(uid));
  }
}
