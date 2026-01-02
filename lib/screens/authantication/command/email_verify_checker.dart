import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'splash.dart';
import '../functions/open_email.dart';
import '../services/session_manager.dart';

import '../../home/customer_home.dart';
import '../../home/employee_dashboard.dart';
import '../../home/owner_dashboard.dart';

class EmailVerifyChecker extends StatefulWidget {
  const EmailVerifyChecker({super.key});

  @override
  State<EmailVerifyChecker> createState() => _EmailVerifyCheckerState();
}

class _EmailVerifyCheckerState extends State<EmailVerifyChecker>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  bool isEmailVerified = false;
  bool canResend = true;

  Timer? timer;
  Timer? cooldownTimer;
  int cooldownRemaining = 0;

  late final AnimationController _entranceController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  // ------------------------------------------------------------
  // INIT
  // ------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _setupAnimations();
    _restoreCooldown();

//...............
    // checkVerification();
    // timer = Timer.periodic(
    //   const Duration(seconds: 3),
    //   (_) => checkVerification(),
    // );
//..........

  }

  // ------------------------------------------------------------
  // ANIMATIONS
  // ------------------------------------------------------------
  void _setupAnimations() {
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _scaleAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    );

    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );

    _entranceController.forward();
  }

  // ------------------------------------------------------------
  // RESTORE COOLDOWN AFTER REFRESH / SLEEP
  // ------------------------------------------------------------
  Future<void> _restoreCooldown() async {
    final prefs = await SessionManager.getPrefs();
    final lastSent = prefs.getInt('lastVerificationSent') ?? 0;

    if (lastSent == 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    const cooldown = 30000;

    final diff = now - lastSent;
    if (diff < cooldown) {
      final remaining = ((cooldown - diff) / 1000).ceil();
      setState(() {
        canResend = false;
        cooldownRemaining = remaining;
      });
      startCooldown(remaining);
    }
  }

  // ------------------------------------------------------------
  // APP RESUME
  // ------------------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkVerification();
    }
  }

  // ------------------------------------------------------------
  // DISPOSE
  // ------------------------------------------------------------
  @override
  void dispose() {
    timer?.cancel();
    cooldownTimer?.cancel();
    _entranceController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ------------------------------------------------------------
  // CHECK EMAIL VERIFIED
  // ------------------------------------------------------------
 Future<void> checkVerification() async {
  final user = supabase.auth.currentUser;

  // session naththam crash wenne na
  if (user == null) {
    debugPrint('No active session');
    return;
  }

  final verified = user.emailConfirmedAt != null;

  if (verified && !isEmailVerified && mounted) {
    timer?.cancel();
    setState(() => isEmailVerified = true);

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    redirectByRole();
  }
}


  // ------------------------------------------------------------
  // ROLE BASED REDIRECT
  // ------------------------------------------------------------
  Future<void> redirectByRole() async {
    String? role = await SessionManager.getUserRole();
    role ??= "customer";

    if (!mounted) return;

    if (role == "business") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OwnerDashboard()),
      );
    } else if (role == "employee") {
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
  }

  // ------------------------------------------------------------
  // COOLDOWN TIMER
  // ------------------------------------------------------------
  void startCooldown(int seconds) {
    cooldownRemaining = seconds;
    cooldownTimer?.cancel();

    cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      if (cooldownRemaining <= 1) {
        t.cancel();
        setState(() {
          canResend = true;
          cooldownRemaining = 0;
        });
      } else {
        setState(() => cooldownRemaining--);
      }
    });
  }

  // ------------------------------------------------------------
  // RESEND EMAIL (USER ACTION ONLY)
  // ------------------------------------------------------------
  Future<void> resendVerification() async {
    final user = supabase.auth.currentUser;
    if (user == null || !mounted) return;

    final prefs = await SessionManager.getPrefs();
    final now = DateTime.now().millisecondsSinceEpoch;

    setState(() => canResend = false);

    await supabase.auth.resend(type: OtpType.signup, email: user.email!);

    await prefs.setInt('lastVerificationSent', now);
    startCooldown(30);
  }

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------
  Future<void> logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  double _cardWidth(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    if (w > 900) return 720;
    if (w > 600) return 520;
    return w - 40;
  }

  // ------------------------------------------------------------
  // UI (UNCHANGED)
  // ------------------------------------------------------------
 @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF3FF), Color(0xFFDDE7FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ScaleTransition(
                scale: _scaleAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    width: _cardWidth(context),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 30,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.mark_email_read_rounded,
                            size: 80, color: Colors.deepPurple),
                        const SizedBox(height: 24),
                        Text(
                          "Verify your email",
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "We’ve sent a verification link to your email.\n"
                          "Open it to continue.\n\n"
                          "This screen updates automatically.",
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 26),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text("Waiting for verification…"),
                          ],
                        ),
                        const SizedBox(height: 30),

                        /// RESEND BUTTON (COOLDOWN VISIBLE)
                        PrimaryOutlineButton(
                          text: canResend
                              ? "Resend Verification Email"
                              : "Wait ${cooldownRemaining}s",
                          onPressed: resendVerification,
                          color: const Color(0xFF1E88E5),
                          icon: Icons.refresh,
                          disabled: !canResend,
                        ),
                        const SizedBox(height: 14),

                        PrimaryOutlineButton(
                          text: "Open Email App",
                          onPressed: () => openEmailApp(
                            context,
                            supabase.auth.currentUser?.email,
                          ),
                          color: const Color(0xFF6A1B9A),
                          icon: Icons.open_in_new,
                        ),
                        const SizedBox(height: 14),

                        PrimaryOutlineButton(
                          text: "Verify Later",
                          onPressed: logout,
                          color: Colors.redAccent,
                          icon: Icons.logout,
                        ),

                        if (isEmailVerified) ...[
                          const SizedBox(height: 26),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.teal),
                              SizedBox(width: 8),
                              Text(
                                "Verified! Redirecting…",
                                style: TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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

// ------------------------------------------------------------
// REUSABLE BUTTON
// ------------------------------------------------------------
class PrimaryOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final IconData icon;
  final bool disabled;

  const PrimaryOutlineButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.color,
    required this.icon,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: disabled ? 0.55 : 1,
        child: OutlinedButton.icon(
          icon: Icon(icon, color: color),
          label: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.12),
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
        ),
      ),
    );
  }
}
