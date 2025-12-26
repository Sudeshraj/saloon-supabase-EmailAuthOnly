import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _keyProfiles = 'profiles';

  /// -------------------------------------------------------
  /// GET all saved profiles
  /// Each profile = ONE ROLE
  /// -------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyProfiles);
    if (raw == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(raw);

      return decoded.map<Map<String, dynamic>>((item) {
        return {
          'email': item['email'] ?? '',
          'name': item['name'] ?? '',
          'password': item['password'] ?? '',
          'photo': item['photo'] ?? '',
          'role': item['role'] ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// -------------------------------------------------------
  /// SAVE profile role by role
  /// If a user has 3 roles → we save 3 profiles
  /// -------------------------------------------------------
  static Future<void> saveProfile(
    String email,
    String name,
    String password,
    List<String> roles, [
    String? photo,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getProfiles();

    final encodedPassword = base64Encode(utf8.encode(password));

    for (String role in roles) {
      // Check if same email + same role exists
      final index = profiles.indexWhere(
        (p) => p['email'] == email && p['role'] == role,
      );

      final data = {
        'email': email,
        'name': name,
        'password': encodedPassword,
        'photo': photo ?? '',
        'role': role, // IMPORTANT: Save as STRING
      };

      if (index != -1) {
        profiles[index] = data; // update
      } else {
        profiles.add(data); // new role-profile
      }
    }

    await prefs.setString(_keyProfiles, jsonEncode(profiles));
  }

  /// -------------------------------------------------------
  /// DELETE ONLY ONE ROLE PROFILE
  /// -------------------------------------------------------
  static Future<void> deleteRoleProfile(String email, String role) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await getProfiles();

    profiles.removeWhere((p) => p['email'] == email && p['role'] == role);

    if (profiles.isEmpty) {
      await prefs.remove(_keyProfiles);
    } else {
      await prefs.setString(_keyProfiles, jsonEncode(profiles));
    }
  }

  static Future<bool> deleteAllProfilesByEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = prefs.getStringList('profiles') ?? [];

    profiles.removeWhere((p) {
      final data = jsonDecode(p);
      return data['email'] == email;
    });

    return prefs.setStringList('profiles', profiles);
  }

  /// -------------------------------------------------------
  /// Clear all
  /// -------------------------------------------------------
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyProfiles);
  }

  /// -------------------------------------------------------
  /// Last logged profile
  /// -------------------------------------------------------
  static Future<Map<String, dynamic>?> getLastUser() async {
    final profiles = await getProfiles();
    if (profiles.isEmpty) return null;
    return profiles.last;
  }

  /// -------------------------------------------------------
  /// Save selected role (for login session)
  /// -------------------------------------------------------
  static Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("userRole", role);
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("userRole");
  }

  /// -------------------------------------------------------
  /// Check if at least one saved profile exists
  /// -------------------------------------------------------
  static Future<bool> hasProfile() async {
    final profiles = await getProfiles();
    return profiles.isNotEmpty;
  }

  /// ✅ Shared prefs helper
  static Future<SharedPreferences> getPrefs() async {
    return await SharedPreferences.getInstance();
  }
}
