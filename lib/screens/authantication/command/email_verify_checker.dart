import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/screens/authantication/command/splash.dart';
import 'package:flutter_application_1/screens/authantication/functions/open_email.dart';
import 'package:flutter_application_1/screens/authantication/services/session_manager.dart';
import 'package:flutter_application_1/screens/home/customer_home.dart';
import 'package:flutter_application_1/screens/home/employee_dashboard.dart';
import 'package:flutter_application_1/screens/home/owner_dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailVerifyChecker extends StatefulWidget {
  final List<String> roles;
  const EmailVerifyChecker({super.key, required this.roles});

  @override
  State<EmailVerifyChecker> createState() => _EmailVerifyCheckerState();
}

class _EmailVerifyCheckerState extends State<EmailVerifyChecker>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  bool isEmailVerified = false;
  bool canResend = true;
  bool _sentOnce = false;

  Timer? timer;
  Timer? cooldownTimer;
  int cooldownRemaining = 0;

  late final AnimationController _entranceController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _sendVerificationOnce();
    _checkPreviousCooldown();
    _setupAnimations();

    checkVerification();
    timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => checkVerification(),
    );
  }

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

  Future<void> _checkPreviousCooldown() async {
    final prefs = await SessionManager.getPrefs();
    final lastSent = prefs.getInt('lastVerificationSent') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const cooldown = 30000;

    if (lastSent > 0) {
      final diff = now - lastSent;
      if (diff < cooldown) {
        final remaining = ((cooldown - diff) / 1000).ceil();
        setState(() {
          canResend = false;
          cooldownRemaining = remaining;
        });
        startCooldown(remaining);
      } else {
        setState(() => canResend = true);
        _sendVerificationOnce();
      }
    } else {
      _sendVerificationOnce();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    cooldownTimer?.cancel();
    _entranceController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkVerification();
    super.didChangeAppLifecycleState(state);
  }

  // =========================================================================================
  // SUPABASE AUTO EMAIL (NO MANUAL SEND)
  // =========================================================================================
  Future<void> _sendVerificationOnce() async {
    final prefs = await SessionManager.getPrefs();
    final sentBefore = prefs.getBool('emailSentOnce') ?? false;
    if (_sentOnce || sentBefore) return;

    final user = supabase.auth.currentUser;
    if (user == null || user.emailConfirmedAt != null) return;

    _sentOnce = true;
    await prefs.setBool('emailSentOnce', true);
    await prefs.setInt(
      'lastVerificationSent',
      DateTime.now().millisecondsSinceEpoch,
    );

    if (mounted) {
      setState(() => canResend = false);
      startCooldown(30);
    }
  }

  // =========================================================================================
  // CHECK EMAIL VERIFIED
  // =========================================================================================
  Future<void> checkVerification() async {
    final res = await supabase.auth.getUser();
    final user = res.user;
    if (user == null) return;

    final verified = user.emailConfirmedAt != null;

    if (!mounted) return;

    if (verified && !isEmailVerified) {
      timer?.cancel();
      setState(() => isEmailVerified = true);

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      redirectByRole();
    }
  }

  void redirectByRole() {
    final role = widget.roles.isNotEmpty ? widget.roles.first : "customer";

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

  void startCooldown(int seconds) {
    cooldownRemaining = seconds;
    cooldownTimer?.cancel();

    cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (cooldownRemaining <= 1) {
        timer.cancel();
        setState(() {
          canResend = true;
          cooldownRemaining = 0;
        });
      } else {
        setState(() => cooldownRemaining--);
      }
    });
  }

  // =========================================================================================
  // RESEND EMAIL (SUPABASE)
  // =========================================================================================
  Future<void> resendVerification() async {
    final user = supabase.auth.currentUser;
    if (user == null || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found. Please sign in again.")),
      );
      return;
    }

    final prefs = await SessionManager.getPrefs();
    final lastSent = prefs.getInt('lastVerificationSent') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const cooldown = 30000;

    if (now - lastSent < cooldown) {
      final remaining = ((cooldown - (now - lastSent)) / 1000).ceil();
      startCooldown(remaining);
      return;
    }

    setState(() => canResend = false);

    try {
      await supabase.auth.resend(type: OtpType.signup, email: user.email!);

      await prefs.setInt('lastVerificationSent', now);
      startCooldown(30);
    } catch (_) {
      if (!mounted) return;
      setState(() => canResend = true);
    }
  }

  Future<void> logout() async {
    final prefs = await SessionManager.getPrefs();
    await prefs.setBool('emailSentOnce', false);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false, // disables both browser and device back
      onPopInvokedWithResult: (didPop, result) {
        // Optional: handle or log the blocked pop attempt
        debugPrint("Back navigation prevented (didPop=$didPop)");
      },
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
                physics: const BouncingScrollPhysics(),
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Container(
                      width: _cardWidth(context),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white..withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12..withValues(alpha: 0.06),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.deepPurple,
                                          Colors.purpleAccent,
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.mark_email_read_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Verify Email",
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 18,
                                        ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "If you don't receive the email, check spam or try 'Resend'.",
                                      ),
                                    ),
                                  );
                                },
                                child: const Text("Help"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Icon(
                            Icons.email_outlined,
                            size: 96,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Verify your email to continue",
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "A verification link was sent to your registered email address. Open it and follow the instructions. After verification you'll be redirected automatically.",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
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
                              Text("Waiting for verification..."),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              ElevatedButton(
                                onPressed: canResend
                                    ? resendVerification
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canResend
                                      ? const Color.fromARGB(255, 182, 162, 236)
                                      : const Color.fromARGB(255, 100, 98, 98),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  style: TextStyle(
                                    color: const Color.fromARGB(
                                      255,
                                      73,
                                      72,
                                      72,
                                    ),
                                  ),
                                  canResend
                                      ? "Resend Email"
                                      : "Wait ${cooldownRemaining}s",
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await openEmailApp(
                                    context,
                                    supabase.auth.currentUser?.email,
                                  );
                                },
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: const Text("Open Email App"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: logout,
                                child: const Text(
                                  "Verify Later",
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 14,
                                  ),
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
