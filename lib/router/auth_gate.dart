import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/authantication/services/session_manager.dart';

class AuthGate {
  static final _supabase = Supabase.instance.client;

  // ------------------------------------------------------------
  // ROLE PICKER (priority: business > employee > customer)
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
  // MAIN REDIRECT LOGIC (OPTIMIZED)
  // ------------------------------------------------------------
  static Future<String?> redirect(String location) async {
    // -------------------------------------------------------
    // 0️⃣ ALWAYS ALLOWED ROUTES (EXIT EARLY)|login,email verify,role check කරන්න එපා directly open වෙන්න allow කරන routes
    // --------------------------------------------------------
    const allowed = {'/', '/login', '/continue', '/verify-email'};

    if (allowed.contains(location)) return null;

    final auth = _supabase.auth;
    final session = auth.currentSession;
    final user = auth.currentUser;

    // --------------------------------------------------------
    // 1️⃣ NOT LOGGED IN
    // --------------------------------------------------------
    if (user == null || session == null) {
      final hasProfiles = (await SessionManager.getProfiles()).isNotEmpty;

      if (hasProfiles && location != '/continue') {
        return '/continue';
      }

      return location == '/login' ? null : '/login';
    }

    // --------------------------------------------------------
    // 2️⃣ EMAIL NOT VERIFIED
    // --------------------------------------------------------

    // if (user.emailConfirmedAt == null) {
    //   return '/verify-email';
    // }

    if (user.emailConfirmedAt == null) {
      return location == '/verify-email' ? null : '/verify-email';
    }

    // --------------------------------------------------------
    // 3️⃣ ROLE RESOLUTION (LOCAL → DB ONCE)
    // --------------------------------------------------------
    String? role = await SessionManager.getUserRole();

    if (role == null) {
      final res = await _supabase
          .from('profiles')
          .select('role, roles')
          .eq('id', user.id)
          .maybeSingle();

      role = _pickRole(res?['role'] ?? res?['roles']);
      await SessionManager.saveUserRole(role);
    }

    // 4️⃣ ROLE BASED ROUTING (PREFIX SAFE)
    bool isIn(String base) => location.startsWith(base);

    switch (role) {
      case 'business':
        return isIn('/owner') ? null : '/owner';
      case 'employee':
        return isIn('/employee') ? null : '/employee';
      default:
        return isIn('/customer') ? null : '/customer';
    }
  }
}
