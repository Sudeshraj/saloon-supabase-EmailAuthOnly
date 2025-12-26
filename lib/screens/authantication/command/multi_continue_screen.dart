import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/authantication/command/email_verify_checker.dart';
import 'package:flutter_application_1/screens/authantication/command/not_you.dart';
import 'package:flutter_application_1/screens/commands/functions/get_firestore_profile.dart';
import 'package:flutter_application_1/screens/commands/alertBox/show_custom_alert.dart';
import '../services/session_manager.dart';
import '../../home/customer_home.dart';
import '../../home/owner_dashboard.dart';
import '../../home/employee_dashboard.dart';
import 'sign_in.dart';
import 'registration_flow.dart';

class ContinueScreen extends StatefulWidget {
  const ContinueScreen({super.key});

  @override
  State<ContinueScreen> createState() => _ContinueScreenState();
}

class _ContinueScreenState extends State<ContinueScreen> {
  List<Map<String, dynamic>> profiles = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final list =
        await SessionManager.getProfiles(); // Already expanded role-by-role
    setState(() => profiles = list);
  }

  // -------------------------------------------------------------
  // LOGIN + EMAIL VERIFY + REDIRECT BY ROLE
  // -------------------------------------------------------------
  Future<void> _handleProfileSelection(Map<String, dynamic> profile) async {
    if (_loading) return;

    setState(() => _loading = true);

    User? user = FirebaseAuth.instance.currentUser;

    // Auto-login with saved credentials if needed
    if (user == null && profile['password'] != null) {
      try {
        final decodedPass = utf8.decode(base64Decode(profile['password']));
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: profile['email'],
              password: decodedPass,
            );

        user = credential.user;
      } catch (e) {
        if (!mounted) return;

        setState(() => _loading = false);
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text("Login failed. Please log in again."),
        //     backgroundColor: Colors.redAccent,
        //   ),
        // );
        await showCustomAlert(
          context,
          title: "Error ❌",
          message: "Login failed. Please log in again",
          isError: true,
          onOk: () async {
            await FirebaseAuth.instance.signOut();
          },
          onClose: () async {
            await FirebaseAuth.instance.signOut();
          },
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SignInScreen()),
        );
        return;
      }
    }

    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    await user.reload();
    user = FirebaseAuth.instance.currentUser;

    // -------------------------------------------------------------
    // EMAIL NOT VERIFIED
    // -------------------------------------------------------------
    if (!user!.emailVerified) {
      if (!mounted) return;
      final safeEmail = user.email ?? '';

      String displayName = "Unknown User";
      String photoUrl = "";
      List<String> roles = [];

      // 🔽 Start login function
      try {
        final result = await getFirestoreProfile(safeEmail);

        if (!mounted) return;

        if (result == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No user found try again.")),
          );
          await FirebaseAuth.instance.signOut();
          return;
        }

        if (result.containsKey("error")) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Firestore error: ${result['error']}")),
          );
          await FirebaseAuth.instance.signOut();
          return;
        }

        // 🔽 Assign INSIDE
        displayName = result["name"] as String? ?? "Unknown User";
        photoUrl = result["photo"] as String? ?? "";
        roles = (result["roles"] as List?)?.cast<String>() ?? [];
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Unexpected error: $e")));
        await FirebaseAuth.instance.signOut();
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NotYouScreen(
            email: safeEmail,
            name: displayName,
            photoUrl: photoUrl,
            roles: roles,
            buttonText: "Not You?",
            page: 'cont',

            // ================== NOT YOU ==================
            onNotYou: () async {
              final nav = navigatorKey.currentState;
              if (nav == null) return;

              final dialogCtx = nav.overlay!.context;

              await showCustomAlert(
                dialogCtx,
                title: "Remove Profile?",
                message: "This role profile will be removed from this device.",
                isError: true,
                buttonText: "Delete",
                onOk: () async {
                  await SessionManager.deleteRoleProfile(
                    safeEmail,
                    profile['role'], // ONLY THIS ROLE
                  );

                  await FirebaseAuth.instance.signOut();

                  nav.pushReplacement(
                    MaterialPageRoute(builder: (_) => const ContinueScreen()),
                  );
                },
                onClose: () async {
                  // await FirebaseAuth.instance.signOut();
                },
              );
            },

            // ================== CONTINUE ==================
            onContinue: () async {
              final nav = navigatorKey.currentState;
              if (nav == null) return;

              // Navigate to email verify screen
              nav.pushReplacement(
                MaterialPageRoute(
                  builder: (_) => EmailVerifyChecker(roles: roles),
                ),
              );
            },
          ),
        ),
      );

      return;
    }

    // -------------------------------------------------------------
    // EMAIL VERIFIED → REDIRECT BY ROLE
    // -------------------------------------------------------------
    final String role = profile['role'];
    if (!mounted) return;
    if (role == "customer") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomerHome()),
      );
    } else if (role == "business") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OwnerDashboard()),
      );
    } else if (role == "employee") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EmployeeDashboard()),
      );
    }

    setState(() => _loading = false);
  }

  // -------------------------------------------------------------
  // POPUP MENU FOR DELETE (ROLE-BY-ROLE)
  // -------------------------------------------------------------
  void _showProfilesMenu(Offset position) async {
    if (profiles.isEmpty) return;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final selected = await showMenu<Map<String, dynamic>>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: const Color(0xFF1C1F26),
      items: profiles
          .map(
            (p) => PopupMenuItem<Map<String, dynamic>>(
              value: p,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage:
                        (p['photo'] != null && p['photo'].toString().isNotEmpty)
                        ? NetworkImage(p['photo'])
                        : null,
                    child: (p['photo'] == null || p['photo'].toString().isEmpty)
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "${p['name']} (${p['role']})",
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () async {
                      await SessionManager.deleteRoleProfile(
                        p['email'],
                        p['role'],
                      );
                      _loadProfiles();

                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );

    if (selected != null) {
      _handleProfileSelection(selected);
    }
  }

  // -------------------------------------------------------------
  // UI DESIGN (unchanged)
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isWeb = screenSize.width > 700;
    final double maxWidth = isWeb ? 450 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1820),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              height: screenSize.height,
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Stack(
                children: [
                  if (profiles.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTapDown: (details) =>
                            _showProfilesMenu(details.globalPosition),
                        child: const Icon(
                          Icons.more_vert,
                          color: Colors.white70,
                        ),
                      ),
                    ),

                  Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: profiles.isEmpty
                              ? const Text(
                                  'No saved profiles',
                                  style: TextStyle(color: Colors.white60),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: profiles
                                      .map(
                                        (p) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: GestureDetector(
                                            onTap: () =>
                                                _handleProfileSelection(p),
                                            child: Card(
                                              color: Colors.white.withValues(
                                                alpha: 0.06,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              elevation: 2,
                                              child: ListTile(
                                                leading: CircleAvatar(
                                                  radius: 25,
                                                  backgroundImage:
                                                      (p['photo'] != null &&
                                                          p['photo']
                                                              .toString()
                                                              .isNotEmpty)
                                                      ? NetworkImage(p['photo'])
                                                      : null,
                                                  child:
                                                      (p['photo'] == null ||
                                                          p['photo']
                                                              .toString()
                                                              .isEmpty)
                                                      ? const Icon(
                                                          Icons.person,
                                                          color: Colors.white,
                                                        )
                                                      : null,
                                                ),
                                                title: Text(
                                                  "${p['name']} (${p['role']} profile)",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                trailing: const Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  color: Colors.white38,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                      ),

                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignInScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Login with another account',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegistrationFlow(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF1877F3),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text(
                                'Create new account',
                                style: TextStyle(
                                  color: Color(0xFF1877F3),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
