import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/authantication/services/session_manager.dart';

class AuthGate {
  static final _supabase = Supabase.instance.client;

  // ------------------------------------------------------------
  // Priority role selector (business > employee > customer)
  // ------------------------------------------------------------
  static String _pickRole(dynamic data) {
    if (data == null) return 'customer';
    if (data is String) return data.toLowerCase();

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

    final isLoggingIn = location == '/login';
    final isVerifying = location == '/verify-email';
    final isContinue = location == '/continue';

    // --------------------------------------------------------
    // 1️⃣ NOT LOGGED IN
    // --------------------------------------------------------
    if (user == null || session == null) {
      final profiles = await SessionManager.getProfiles();

      if (profiles.isNotEmpty) {
        // if local profiles exist → show continue screen
        return isContinue ? null : '/continue';
        //  return isVerifying ? null : '/verify-email';
      }

      // no profiles → go to login
      return isLoggingIn ? null : '/login';
    }

    // --------------------------------------------------------
    // 2️⃣ EMAIL NOT VERIFIED
    // --------------------------------------------------------
    if (user.emailConfirmedAt == null) {
      return isVerifying ? null : '/verify-email';
    }

    // --------------------------------------------------------
    // 3️⃣ RESOLVE ROLE (from local first → DB fallback)
    // --------------------------------------------------------
    String? role = await SessionManager.getUserRole();

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
        role = 'customer';
      }
    }

    role ??= 'customer';

    // --------------------------------------------------------
    // 4️⃣ ROLE BASED REDIRECT
    // --------------------------------------------------------
    switch (role) {
      case 'business':
        return location == '/owner' ? null : '/owner';
      case 'employee':
        return location == '/employee' ? null : '/employee';
      case 'customer':
      default:
        return location == '/customer' ? null : '/customer';
    }
  }
}
