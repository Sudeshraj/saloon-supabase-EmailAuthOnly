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

    checkVerification();
    timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => checkVerification(),
    );
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
    final res = await supabase.auth.getUser();
    final user = res.user;
    if (user == null) return;

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

    await supabase.auth.resend(
      type: OtpType.signup,
      email: user.email!,
    );

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

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFf7fbff), Color(0xFFE8F0FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 16,
                ),
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Container(
                      width: _cardWidth(context),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.94),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 30,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mark_email_read_rounded,
                            size: 96,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Verify your email",
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "We’ve sent a verification link to your email. "
                            "Open it to continue. This screen will update automatically.",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text("Waiting for verification…"),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed:
                                    canResend ? resendVerification : null,
                                child: Text(
                                  canResend
                                      ? "Resend Email"
                                      : "Wait ${cooldownRemaining}s",
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => openEmailApp(
                                  context,
                                  supabase.auth.currentUser?.email,
                                ),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text("Open Email App"),
                              ),
                              TextButton(
                                onPressed: logout,
                                child: const Text(
                                  "Verify Later",
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                          if (isEmailVerified) ...[
                            const SizedBox(height: 20),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: Colors.teal),
                                SizedBox(width: 8),
                                Text(
                                  "Verified! Redirecting…",
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.w600,
                                  ),
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
      ),
    );
  }
}
