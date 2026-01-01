import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate {
  static final _supabase = Supabase.instance.client;

  // ------------------------------------------------------------
  // ROLE PICKER (priority: business > employee > customer)
  // ------------------------------------------------------------
  static String pickRole(dynamic data) {
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
  // PURE REDIRECT LOGIC (ASYNC but NO await)
  // ------------------------------------------------------------
  static Future<String?> redirect(String location) async {
    const allowed = {'/', '/login', '/continue', '/verify-email'};
    if (allowed.contains(location)) return null;

    final user = _supabase.auth.currentUser;
    final session = _supabase.auth.currentSession;

    // not logged in
    if (user == null || session == null) {
      return location == '/login' ? null : '/login';
    }

    // email not verified
    if (user.emailConfirmedAt == null) {
      return location == '/verify-email' ? null : '/verify-email';
    }

    // logged in & verified → Splash handles role routing
    return null;
  }
}
