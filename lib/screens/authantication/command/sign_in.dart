import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/authantication/command/email_verify_checker.dart';
import 'package:flutter_application_1/screens/authantication/functions/delete_user.dart';
import 'package:flutter_application_1/screens/commands/functions/get_firestore_profile.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/commands/alertBox/reset_password.dart';
import 'package:flutter_application_1/screens/home/employee_dashboard.dart';
import 'package:flutter_application_1/screens/home/owner_dashboard.dart';
import 'package:flutter_application_1/screens/commands/alertBox/show_custom_alert.dart';
import 'package:flutter_application_1/screens/authantication/command/registration_flow.dart';
import 'package:flutter_application_1/screens/home/customer_home.dart';
import 'package:flutter_application_1/screens/authantication/command/multi_continue_screen.dart';
import 'package:flutter_application_1/screens/authantication/command/not_you.dart';
import 'package:flutter_application_1/screens/authantication/services/session_manager.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;

  bool _obscurePassword = true;
  bool _loading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String? _emailError;
  String? _passwordError;
  bool _isValid = false;
  bool _isValidEmail = false;
  bool _hasSavedProfile = false;

  @override
  void initState() {
    super.initState();
    _checkSavedProfile();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();

    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  bool _isValidEmailFormat(String value) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(value);
  }

  void _validateForm() {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    setState(() {
      if (email.isEmpty) {
        _emailError = 'Enter your email address';
        _isValidEmail = false;
      } else if (!_isValidEmailFormat(email)) {
        _emailError = 'Enter a valid email address';
        _isValidEmail = false;
      } else {
        _emailError = null;
        _isValidEmail = true;
      }

      if (password.isEmpty) {
        _passwordError = 'Enter your password';
      } else {
        _passwordError = null;
      }

      _isValid = _emailError == null && _passwordError == null;
    });
  }

  Future<void> _checkSavedProfile() async {
    final profiles = await SessionManager.getProfiles();
    setState(() {
      _hasSavedProfile = profiles.isNotEmpty;
    });
  }

  Future<void> loginUser() async {
    try {
      setState(() => _loading = true);

      final credential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if (user == null) return;

      await user.reload();
      if (!user.emailVerified) {
        if (!mounted) return;
        final safeEmail = user.email ?? '';

        String displayName = "Unknown User";
        String photoUrl = "";
        String uid = "";
        List<String> roles = [];

        // Start login function
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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("try again.")));
            debugPrint("Firestore error: ${result['error']}");
            await FirebaseAuth.instance.signOut();
            return;
          }

          //  Assign INSIDE
          displayName = result["name"] as String? ?? "Unknown User";
          photoUrl = result["photo"] as String? ?? "";
          uid = result["uid"] as String? ?? "";
          roles = (result["roles"] as List?)?.cast<String>() ?? [];
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No user found try again.")),
          );
          debugPrint("Firebase error code: $e");
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
              page: 'splash',

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
                    final success = await AuthHelper.deleteUserUsingUid(uid);

                    if (!success) {
                      messengerKey.currentState?.showSnackBar(
                        const SnackBar(
                          content: Text("Delete failed. Try again."),
                        ),
                      );
                      return;
                    }

                    nav.pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const RegistrationFlow(),
                      ),
                    );
                  },
                  onClose: () {
                    FirebaseAuth.instance.signOut();
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

      // ALWAYS load Firestore profile after successful login
      final profile = await getFirestoreProfile(user.email!);

      // extract Firestore fields safely
      String savedName =
          profile?["name"] as String? ?? user.displayName ?? user.email!;
      String savedPhoto = profile?["photo"] as String? ?? "";
      List<String> savedRoles =
          (profile?["roles"] as List?)?.cast<String>() ?? [];

      // Load role using getUserRole (your method returns a STRING)
      final role = await getUserRole(user.email!);

      // Save selected role if exists
      if (role != null) {
        await SessionManager.saveUserRole(role);

        // If Firestore roles list was empty, add the role here
        if (savedRoles.isEmpty) {
          savedRoles = [role];
        }
      }

      // Fallback if still no role
      if (savedRoles.isEmpty) {
        savedRoles = ["customer"];
      }

      //  Save FULL profile locally using your saveProfile()
      await SessionManager.saveProfile(
        user.email!,
        savedName,
        _passwordController.text.trim(),
        savedRoles, // LIST<String>
        savedPhoto, // photo
      );

      if (!mounted) return;

      final redirectRole = role ?? savedRoles.first;

      if (redirectRole == "customer") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHome()),
        );
      } else if (redirectRole == "business") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OwnerDashboard()),
        );
      } else if (redirectRole == "employee") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EmployeeDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHome()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-credential':
          message = "Invalid email or password.";
          break;

        case 'invalid-email':
          message = "Enter a valid email address.";
          break;

        case 'user-disabled':
          message = "This account has been disabled.";
          break;

        case 'too-many-requests':
          message = "Too many attempts. Please try again later.";
          break;

        default:
          message = "Login failed";
          debugPrint("Firebase error code: ${e.code}");
          debugPrint("Firebase error message: ${e.message}");
      }

      if (!mounted) return;

      await showCustomAlert(
        context,
        title: "Login Error ❌",
        message: message,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF0F1820);
    final size = MediaQuery.of(context).size;
    final bool isWeb = size.width > 700;
    final double maxWidth = isWeb ? 480 : double.infinity;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Container(
                  height: size.height - 40, // same height as Welcome screen
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Arrow (inside frame)
                      if (_hasSavedProfile)
                        Align(
                          alignment: Alignment.topLeft,
                          child: Builder(
                            builder: (innerContext) => IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: () {
                                Navigator.pushReplacement(
                                  innerContext,
                                  MaterialPageRoute(
                                    builder: (_) => const ContinueScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                      // Main content
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 10),
                              Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF1877F3),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Log in to MySalon',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Email field
                              TextField(
                                controller: _emailController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Email address',
                                  hintStyle: const TextStyle(
                                    color: Colors.white54,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.05,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: _isValidEmail
                                          ? const Color(0xFF1877F3)
                                          : Colors.redAccent,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: _emailController.text.isEmpty
                                      ? null
                                      : _isValidEmail
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF4CAF50),
                                        )
                                      : const Icon(
                                          Icons.error_outline,
                                          color: Colors.redAccent,
                                        ),
                                  errorText: _emailError,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  hintStyle: const TextStyle(
                                    color: Colors.white54,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.05,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF1877F3),
                                    ),
                                  ),
                                  errorText: _passwordError,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.white70,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Log in Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isValid && !_loading
                                      ? loginUser
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1877F3),
                                    disabledBackgroundColor: Colors.white12,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: _loading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : const Text(
                                          'Log in',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Forgot password
                              GestureDetector(
                                onTap: () {
                                  showResetPasswordDialog(context);
                                },
                                child: const Text(
                                  'Forgotten password?',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom buttons
                      Column(
                        children: [
                          const SizedBox(height: 14),
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
                                backgroundColor: const Color(
                                  0xFF1877F3,
                                ).withValues(alpha: 0.1),
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
                          const SizedBox(height: 30),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
