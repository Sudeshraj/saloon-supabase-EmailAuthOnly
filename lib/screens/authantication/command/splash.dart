import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
              'Checking session...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
