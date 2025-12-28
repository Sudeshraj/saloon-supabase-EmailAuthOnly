import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/authantication/services/session_manager.dart';

class AuthGate {
  static final _supabase = Supabase.instance.client;

  // ------------------------------------------------------------
  // Priority role selector (business > employee > customer)
  // ------------------------------------------------------------
  static String _pickRole(dynamic data) {
    if (data == null) return 'customer';

    if (data is String) {
      return data.toLowerCase();
    }

    if (data is List) {
      final roles = data.map((e) => e.toString().toLowerCase()).toList();

      if (roles.contains('business')) return 'business';
      if (roles.contains('employee')) return 'employee';
      if (roles.contains('customer')) return 'customer';
    }

    return 'customer';
  }

  // ------------------------------------------------------------
  // MAIN REDIRECT LOGIC (GoRouter compatible)
  // ------------------------------------------------------------
  static Future<String?> redirect(String location) async {
    final session = _supabase.auth.currentSession;
    final user = _supabase.auth.currentUser;

    // --------------------------------------------------------
    // 0️⃣ User logged in → EMAIL VERIFICATION FIRST
    // --------------------------------------------------------
    if (user != null) {
      final isEmailVerified = user.emailConfirmedAt != null;

      if (!isEmailVerified) {
        return location == '/verify-email' ? null : '/verify-email';
      }
    }

    // --------------------------------------------------------
    // 1️⃣ Active session → redirect by role
    // --------------------------------------------------------
    if (user != null && session != null) {
      String? role = await SessionManager.getUserRole();

      // --------------------------------------------
      // No local role → fetch from Supabase profile
      // --------------------------------------------
      if (role == null) {
        try {
          final res = await _supabase
              .from('profiles')
              .select('role, roles')
              .eq('id', user.id)
              .maybeSingle();

          if (res != null) {
            final dynamic roleField = res['role'] ?? res['roles'];
            role = _pickRole(roleField);
            await SessionManager.saveUserRole(role);
          }
        } catch (_) {
          // ignore
        }
      }

      // --------------------------------------------
      // Redirect by resolved role (SAFE)
      // --------------------------------------------
      if (role == 'business') {
        return location == '/owner' ? null : '/owner';
      }

      if (role == 'employee') {
        return location == '/employee' ? null : '/employee';
      }

      if (role == 'customer') {
        return location == '/customer' ? null : '/customer';
      }

      return location == '/customer' ? null : '/customer';
    }

    // --------------------------------------------------------
    // 2️⃣ No session → check saved local profiles
    // --------------------------------------------------------
    final profiles = await SessionManager.getProfiles();
    if (profiles.isNotEmpty) {
      return location == '/continue' ? null : '/continue';
    }

    // --------------------------------------------------------
    // 3️⃣ No session & no profiles → Login
    // --------------------------------------------------------
    return location == '/login' ? null : '/login';
  }
}
