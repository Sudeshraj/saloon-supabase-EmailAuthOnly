import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/authantication/functions/delete_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/authantication/command/registration_flow.dart';
import 'package:flutter_application_1/screens/authantication/command/not_you.dart';
import 'package:flutter_application_1/screens/authantication/command/splash.dart';
import 'package:flutter_application_1/screens/authantication/command/email_verify_checker.dart';
import 'package:flutter_application_1/screens/authantication/functions/loading_overlay.dart';
import 'package:flutter_application_1/screens/commands/alertBox/reset_password_onfirm.dart';
import 'package:flutter_application_1/screens/commands/alertBox/show_custom_alert.dart';

import '../models/user.dart';
import 'session_manager.dart';

class SaveUser {
  final SupabaseClient supabase = Supabase.instance.client;

  // =========================================================================================
  // SAFE DATABASE WRITE
  // =========================================================================================
  Future<void> safeWrite(String uid, Map<String, dynamic> data) async {
    int retries = 0;

    while (retries < 3) {
      try {
        await supabase
            .from('profiles')
            .insert({'id': uid, ...data})
            .timeout(const Duration(seconds: 10));
        return;
      } catch (_) {
        retries++;
        if (retries == 3) {
          throw Exception("Database write failed.");
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  // =========================================================================================
  // SUCCESS FLOW — VERIFIED USER
  // =========================================================================================
  Future<void> handleVerifiedFlow(
    BuildContext context,
    User existUser,
    String email,
    List<String> roles,
  ) async {
    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NotYouScreen(
          email: email,
          name: existUser.userMetadata?['name'] ?? "",
          photoUrl: "",
          roles: roles,
          buttonText: "Change Password",
          page: 'signup',

          onNotYou: () async {
            final nav = navigatorKey.currentState;
            if (nav == null) return;
            await showResetPasswordConfirmDialog(
              nav.overlay!.context,
              email: email,
            );
          },

          onContinue: () async {
            await supabase.auth.signOut();
            navigatorKey.currentState?.pushReplacement(
              MaterialPageRoute(builder: (_) => SplashScreen()),
            );
          },
        ),
      ),
    );
  }

  // =========================================================================================
  // NOT VERIFIED FLOW
  // =========================================================================================
  Future<void> handleNotVerifiedFlow(
    BuildContext context,
    User existUser,
    String email,
    List<String> roles,
  ) async {
    if (!context.mounted) return;

    final uid = existUser.id; // 🔁 firebase uid → supabase id

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NotYouScreen(
          email: email,
          name: existUser.userMetadata?['name'] ?? "",
          photoUrl: "",
          roles: roles,
          buttonText: "Not You?",
          page: 'signup',

          // ================== NOT YOU ==================
          onNotYou: () async {
            final nav = navigatorKey.currentState;
            if (nav == null) return;

            final dialogCtx = nav.overlay!.context;

            await showCustomAlert(
              dialogCtx,
              title: "Delete Account?",
              message: "Are you sure you want to delete this profile?",
              isError: true,
              buttonText: "Delete",
              onOk: () async {
                // ⚠️ replace with your backend / edge function
                final success = await AuthHelper.deleteUserUsingUid(uid);

                if (!success) {
                  messengerKey.currentState?.showSnackBar(
                    const SnackBar(content: Text("Delete failed. Try again.")),
                  );
                  return;
                }

                await Supabase.instance.client.auth.signOut();

                nav.pushReplacement(
                  MaterialPageRoute(builder: (_) => const RegistrationFlow()),
                );
              },

              // 🚫 same behavior as before
              onClose: () async {},
            );
          },

          // ================== CONTINUE ==================
          onContinue: () async {
            final nav = navigatorKey.currentState;
            if (nav == null) return;

            nav.pushReplacement(
              MaterialPageRoute(
                builder: (_) => EmailVerifyChecker(roles: roles),
              ),
            );
          },
        ),
      ),
    );

    return; // ✅ THIS IS THE FIX
  }

  // =========================================================================================
  // EMAIL EXISTS HANDLER
  // =========================================================================================
  Future<void> handleEmailAlreadyInUse(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user!;
      final isVerified = user.emailConfirmedAt != null;

      final data = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      final roles = List<String>.from(data['role']);

      if (isVerified) {
        if (!context.mounted) return;
        await handleVerifiedFlow(context, user, email, roles);
      } else {
        if (!context.mounted) return;
        await handleNotVerifiedFlow(context, user, email, roles);
      }
    } catch (_) {
      if (!context.mounted) return;
      await showCustomAlert(
        context,
        title: "Email Already Registered",
        message: "Wrong password. Use Forgot Password.",
        isError: true,
      );
    }
  }

  // =========================================================================================
  // REGISTER ACCOUNT
  // =========================================================================================
  Future<User> registerAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': displayName},
    );

    return res.user!;
  }

  // =========================================================================================
  // SAVE CUSTOMER
  // =========================================================================================
  Future<void> saveUser(CustomerAuth user, BuildContext context) async {
    LoadingOverlay.show(context, message: "Creating your account...");

    try {
      final supaUser = await registerAccount(
        email: user.email,
        password: user.password,
        displayName: user.firstName,
      );

      await safeWrite(supaUser.id, {
        'role': user.roles,
        'name': '${user.firstName} ${user.lastName}' ,       
        'email': user.email,
        'verified': false,
      });

      LoadingOverlay.hide();

      await SessionManager.saveProfile(
        user.email,
        user.firstName,
        user.password,
        user.roles,
        null,
      );
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerifyChecker(roles: user.roles),
        ),
      );
    } catch (e) {
      LoadingOverlay.hide();
      if (!context.mounted) return;
      if (e.toString().contains("User already registered")) {
        return handleEmailAlreadyInUse(context, user.email, user.password);
      }

      await showCustomAlert(
        context,
        title: "Error",
        message: e.toString(),
        isError: true,
      );
    }
  }

  // =========================================================================================
  // SAVE COMPANY
  // =========================================================================================
  Future<void> saveCompany(CompanyAuth user, BuildContext context) async {
    LoadingOverlay.show(context, message: "Registering your business...");

    try {
      final supaUser = await registerAccount(
        email: user.email,
        password: user.password,
        displayName: user.companyName,
      );

      await safeWrite(supaUser.id, {
        'role': user.roles,
        'name': user.companyName,
        'email': user.email,
        'verified': false,
      });

      LoadingOverlay.hide();

      await SessionManager.saveProfile(
        user.email,
        user.companyName,
        user.password,
        user.roles,
        null,
      );
 if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerifyChecker(roles: user.roles),
        ),
      );
    } catch (e) {
      LoadingOverlay.hide();
      await showCustomAlert(
        context,
        title: "Error",
        message: e.toString(),
        isError: true,
      );
    }
  }
}
