import 'package:shared_preferences/shared_preferences.dart';

class AppState {
  static const String _branchIdKey = 'current_branch_id';
  static const String _branchNameKey = 'current_branch_name';
  static const String _branchAddressKey = 'current_branch_alamat';
  static const String _roleKey = 'current_role';
  static const String _branchOverrideKey = 'branch_override';

  static Future<void> saveBranch({
    required String? branchId,
    String? branchName,
    String? branchAddress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (branchId != null) {
      await prefs.setString(_branchIdKey, branchId);
    } else {
      await prefs.remove(_branchIdKey);
    }
    if (branchName != null) {
      await prefs.setString(_branchNameKey, branchName);
    } else {
      await prefs.remove(_branchNameKey);
    }
    if (branchAddress != null) {
      await prefs.setString(_branchAddressKey, branchAddress);
    } else {
      await prefs.remove(_branchAddressKey);
    }
  }

  static Future<String?> getBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_branchIdKey);
  }

  static Future<String?> getBranchName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_branchNameKey);
  }

  static Future<String?> getBranchAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_branchAddressKey);
  }

  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<void> setBranchOverride(String branchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_branchOverrideKey, branchId);
    await prefs.setString(_branchIdKey, branchId);
  }

  static Future<String?> getBranchOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_branchOverrideKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_branchIdKey);
    await prefs.remove(_branchNameKey);
    await prefs.remove(_branchAddressKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_branchOverrideKey);
  }
}
