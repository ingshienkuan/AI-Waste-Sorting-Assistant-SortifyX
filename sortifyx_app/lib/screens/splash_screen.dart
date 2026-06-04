import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Splash screen.
///
/// While showing the logo, it checks whether a saved access token is still
/// valid (by hitting /auth/me). If valid, navigates directly to the
/// appropriate home (admin or user). Otherwise navigates to login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Minimum splash duration for visual polish
    final delay = Future.delayed(const Duration(seconds: 2));
    String nextRoute = '/login';

    final token = await ApiService.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final res = await ApiService.get('/auth/me');
        if (res.statusCode == 200) {
          final user = jsonDecode(res.body)['user'] as Map<String, dynamic>;
          nextRoute =
              (user['is_admin'] == true) ? '/admin-dashboard' : '/home';
        } else {
          // Stale / revoked token
          await ApiService.clearToken();
        }
      } catch (_) {
        // Offline or backend down — fall through to login.
      }
    }

    await delay;
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5CB85C),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              child: Icon(Icons.recycling, size: 60, color: Color(0xFF5CB85C)),
            ),
            SizedBox(height: 24),
            Text(
              'SortifyX',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}
