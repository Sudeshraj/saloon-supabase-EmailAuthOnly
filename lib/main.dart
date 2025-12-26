import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/screens/authantication/functions/loading_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'screens/authantication/command/splash.dart';
import 'screens/net_disconnect/network_service.dart';
import 'screens/net_disconnect/network_banner.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase offline mode — ignore
  }

  /// 🟢 Supabase Init (safe offline)
  try {
    await Supabase.initialize(
      url: 'https://ifhenrgfpahandumdwmt.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlmaGVucmdmcGFoYW5kdW1kd210Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY0NTY5OTcsImV4cCI6MjA4MjAzMjk5N30.HgiUZJkXCtzXpl0zfheAx2l4qcdFLMmzOwjSYMcYkp0',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } catch (e) {
    // Supabase offline mode — ignore
  }

  // 🔥 Register navigatorKey for global LoadingOverlay
  LoadingOverlay.setNavigatorKey(navigatorKey);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final NetworkService _networkService;
  StreamSubscription<bool>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();

    _networkService = NetworkService();

    // 🔥 Listen to network changes
    _sub = _networkService.onStatusChange.listen((online) {
      if (!mounted) return;

      setState(() {
        _offline = !online;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _networkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // REQUIRED for loader
      scaffoldMessengerKey: messengerKey, // Toasts/snackbars
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),

      builder: (context, child) {
        return Stack(
          children: [
            // ---- UI lock when offline ----
            AbsorbPointer(
              absorbing: _offline,
              child: ColorFiltered(
                colorFilter: _offline
                    ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                    : const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.multiply,
                      ),
                child: child,
              ),
            ),

            // ---- Offline banner at bottom ----
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(child: NetworkBanner(offline: _offline)),
            ),
          ],
        );
      },

      home: const SplashScreen(),
    );
  }
}
