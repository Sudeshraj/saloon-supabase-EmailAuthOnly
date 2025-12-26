// lib/screens/authantication/command/splash.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/screens/authantication/command/email_verify_checker.dart';
import 'package:flutter_application_1/screens/home/employee_dashboard.dart';
import 'package:flutter_application_1/screens/home/owner_dashboard.dart';
import 'package:flutter_application_1/screens/authantication/command/multi_continue_screen.dart';
import 'package:flutter_application_1/screens/authantication/command/sign_in.dart';
import '../services/session_manager.dart';
import '../../home/customer_home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  // ------------------------------------------------------------
  // Priority role selector (business > employee > customer)
  // ------------------------------------------------------------
  String pickRole(dynamic data) {
    if (data == null) return "customer";

    // Case 1: role is a single string
    if (data is String) {
      return data.toLowerCase();
    }

    // Case 2: role list
    if (data is List) {
      final roles = data.map((e) => e.toString().toLowerCase()).toList();

      if (roles.contains("business")) return "business";
      if (roles.contains("employee")) return "employee";
      if (roles.contains("customer")) return "customer";
    }

    return "customer"; // fallback
  }

  // ------------------------------------------------------------
  // CHECK SESSION UPDATED
  // ------------------------------------------------------------
  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 1)); // small splash

    final user = FirebaseAuth.instance.currentUser;
    final profiles = await SessionManager.getProfiles();

    // -------------------------------------------------------
    // 0️⃣ If Firebase user exists → force emailVerified check FIRST
    // -------------------------------------------------------
    if (user != null) {
      try {
        await user.reload();
      } catch (_) {
        // ignore network errors for reload
      }

      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser != null && (updatedUser.emailVerified == false)) {
        // Try to pass a best-effort local role if available
        String? localRole = await SessionManager.getUserRole();
        final rolesList = localRole != null ? [localRole] : <String>[];

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => EmailVerifyChecker(roles: rolesList)),
        );
        return;
      }
    }

    // -------------------------------------------------------
    // 1️⃣ If Firebase user exists → redirect by role (only if verified)
    // -------------------------------------------------------
    if (user != null) {
      String? role = await SessionManager.getUserRole();

      //  If no local role → load from Firestore
      // 🔎 Try to find role in Firestore using several strategies
      if (role == null && user.email != null) {
        try {
          // 1) Try document by email (old approach)
          final docByEmail = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.email!)
              .get();

          Map<String, dynamic>? data;
          if (docByEmail.exists) {
            data = docByEmail.data();
          } else {
            // 2) Try document by UID
            final docByUid = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            if (docByUid.exists) {
              data = docByUid.data();
            } else {
              // 3) Query where a field `email` equals the user's email
              final queryByEmail = await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: user.email)
                  .limit(1)
                  .get();
              if (queryByEmail.docs.isNotEmpty) {
                data = queryByEmail.docs.first.data() as Map<String, dynamic>?;
              } else {
                // 4) attempt lowercased email query (if you stored lowercase)
                final queryLower = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: user.email!.toLowerCase())
                    .limit(1)
                    .get();
                if (queryLower.docs.isNotEmpty) {
                  data = queryLower.docs.first.data() as Map<String, dynamic>?;
                }
              }
            }
          }

          // If we found data, pick role and save locally
          if (data != null) {
            final dynamic roleField = data['role'] ?? data['roles'];
            final picked = pickRole(roleField);
            role = picked;
            await SessionManager.saveUserRole(role);
          }
        } catch (e) {
          // ignore firestore read errors
        }
      }

      if (!mounted) return;

      // -------------------------------------------------------
      // 🔥 Redirect based on final role
      // -------------------------------------------------------
      if (role == "business") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OwnerDashboard()),
        );
        return;
      }

      if (role == "employee") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EmployeeDashboard()),
        );
        return;
      }

      if (role == "customer") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHome()),
        );
        return;
      }

      // fallback
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomerHome()),
      );
      return;
    }

    // -------------------------------------------------------
    // 2️⃣ Saved profiles exist → ContinueScreen
    // -------------------------------------------------------
    if (profiles.isNotEmpty) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ContinueScreen()),
      );
      return;
    }

    // -------------------------------------------------------
    // 3️⃣ No session → Login Screen
    // -------------------------------------------------------
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F1820),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text('Loading...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
