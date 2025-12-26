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
import 'session_manager.dart';

class SaveUser {
  final SupabaseClient supabase = Supabase.instance.client;

  // =========================================================================================
  // SAFE DATABASE WRITE (Retry logic)
  // =========================================================================================
  Future<void> safeWriteProfile(Map<String, dynamic> data) async {
    int retries = 0;
    while (retries < 3) {
      try {
        await supabase.from('profiles').insert(data);
        return;
      } catch (e) {
        retries++;
        if (retries == 3) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  // =========================================================================================
  // REGISTER ACCOUNT (auth signup)
  // =========================================================================================
  Future<AuthResponse> registerAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': displayName},
    );

    if (res.user == null) {
      throw Exception("User registration failed.");
    }

    return res;
  }

  // =========================================================================================
  // CREATE PROFILE (insert into profiles table)
  // =========================================================================================
  Future<void> createProfile({
    required String userId,
    required String roleName,
    required String displayName,
    Map<String, dynamic>? extraData,
  }) async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      throw Exception("No active Supabase session found — please sign in first.");
    }

    final roleRes = await supabase
        .from('roles')
        .select('id')
        .eq('name', roleName)
        .maybeSingle();

    if (roleRes == null) {
      throw Exception("Role '$roleName' not found in roles table");
    }

    await safeWriteProfile({
      'user_id': userId,
      'role_id': roleRes['id'],
      'display_name': displayName,
      'extra_data': extraData ?? {},
      'is_active': true,
    });
  }

  // =========================================================================================
  // REGISTER NEW USER WITH ROLE (FULL FIXED FLOW)
  // =========================================================================================
Future<void> registerUserWithRole(
  BuildContext context, {
  required String role,
  required String email,
  required String password,
  required String displayName,
  Map<String, dynamic>? extraData,
}) async {
  LoadingOverlay.show(context, message: "Creating your $role account...");

  try {
    // Step 1 — Register Supabase user
    final res = await registerAccount(
      email: email,
      password: password,
      displayName: displayName,
    );

    final supaUser = res.user!;

    // Step 2 — Try to sign in again (to activate JWT for RLS)
    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // ⚠️ If email not confirmed yet, ignore this error
      if (!e.toString().contains("email_not_confirmed")) {
        rethrow;
      }
    }

    // Step 3 — Create profile (RLS works only with active session)
    await createProfile(
      userId: supaUser.id,
      roleName: role,
      displayName: displayName,
      extraData: extraData,
    );

    // Step 4 — Save locally (for auto-login & continue flow)
    await SessionManager.saveProfile(
      email: email,
      name: displayName,
      password: password,
      roles: [role],
      photo: null,
    );

    LoadingOverlay.hide();

    // Step 5 — Move to email verify screen (always show it after registration)
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EmailVerifyChecker(roles: [role]),
      ),
    );
  } catch (e) {
    LoadingOverlay.hide();
    if (!context.mounted) return;

    if (e.toString().contains("User already registered")) {
      return handleEmailAlreadyInUse(context, email, password);
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
  // ADDITIONAL PROFILE FOR EXISTING USER
  // =========================================================================================
  Future<void> addNewProfileForExistingUser(
    BuildContext context, {
    required String role,
    required String displayName,
    Map<String, dynamic>? extraData,
  }) async {
    LoadingOverlay.show(context, message: "Creating your $role profile...");

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception("No logged-in user found. Please sign in first.");
      }

      final email = currentUser.email ?? '';
      final profiles = await SessionManager.getProfiles();

      String existingPassword = '';
      if (profiles.isNotEmpty) {
        final firstProfile = profiles.firstWhere(
          (p) => p['email'] == email,
          orElse: () => {},
        );
        if (firstProfile.isNotEmpty) {
          final existingRole = firstProfile['role'];
          existingPassword =
              await SessionManager.getPassword(email, existingRole) ?? '';
        }
      }

      await createProfile(
        userId: currentUser.id,
        roleName: role,
        displayName: displayName,
        extraData: extraData,
      );

      await SessionManager.saveProfile(
        email: email,
        name: displayName,
        password: existingPassword,
        roles: [role],
        photo: null,
      );

      LoadingOverlay.hide();

      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => EmailVerifyChecker(roles: [role])),
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

  // =========================================================================================
  // HANDLE EMAIL ALREADY REGISTERED
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

      final profiles = await supabase
          .from('profiles')
          .select('roles(name)')
          .eq('user_id', user.id);

      final roles =
          profiles.map<String>((e) => e['roles']['name'].toString()).toList();

      if (!context.mounted) return;

      if (isVerified) {
        await handleVerifiedFlow(context, user, email, roles);
      } else {
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
  // VERIFIED FLOW
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
    final uid = existUser.id;

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
              onClose: () async {},
            );
          },
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
  }
}
