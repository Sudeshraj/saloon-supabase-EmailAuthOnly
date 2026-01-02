import 'package:flutter/material.dart';
import 'package:flutter_application_1/router/auth_gate.dart';
import 'package:flutter_application_1/screens/authantication/services/session_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _decideRoute();
  }

  // ------------------------------------------------------------
  // 🔑 ALL ASYNC DECISION LOGIC (SAFE PLACE)
  // ------------------------------------------------------------
  Future<void> _decideRoute() async {
    final supabase = _supabase;

    // 1️⃣ Wait for deep-link session
    await SessionManager.waitForSession();
    if (!mounted) return;

    final session = supabase.auth.currentSession;
    final user = supabase.auth.currentUser;

    // 2️⃣ NOT logged in → no refresh
    if (user == null || session == null) {
      context.go('/login');
      return;
    }

    // 3️⃣ Safe refresh (ONLY if session exists)
    try {
      await supabase.auth.refreshSession();
    } catch (_) {
      if (!mounted) return;
      context.go('/login');
      return;
    }

    if (!mounted) return;

    // 4️⃣ Email not verified user kenek innavanam vitharai meka valid
    if (user.emailConfirmedAt == null) {
      context.go('/verify-email');
      return;
    }

    // 5️⃣ Resolve role
    String? role = await SessionManager.getUserRole();
    if (!mounted) return;

    if (role == null) {
      final res = await supabase
          .from('profiles')
          .select('role, roles')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      role = AuthGate.pickRole(res?['role'] ?? res?['roles']);
      await SessionManager.saveUserRole(role);
      if (!mounted) return;
    }

    // 6️⃣ Navigate safely
    switch (role) {
      case 'business':
        context.go('/owner');
        break;
      case 'employee':
        context.go('/employee');
        break;
      default:
        context.go('/customer');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔹 App logo (optional)
            // Image.asset(
            //   'assets/logo.png',
            //   height: 120,
            // ),
            SizedBox(height: 24),

            CircularProgressIndicator(),

            SizedBox(height: 16),

            Text(
              'LOADING',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
