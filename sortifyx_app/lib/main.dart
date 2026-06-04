import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/scan_result_screen.dart';
import 'screens/history_screen.dart';
import 'screens/rewards_screen.dart';
import 'screens/badge_collection_screen.dart';
import 'screens/badge_details_screen.dart';
import 'screens/points_history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_user_statistics_screen.dart';
import 'screens/admin/admin_user_details_screen.dart';
import 'screens/admin/admin_settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SortifyXApp());
}

class SortifyXApp extends StatelessWidget {
  const SortifyXApp({super.key});

  static const _primary = Color(0xFF5CB85C);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SortifyX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: _primary,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
          primary: _primary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _primary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _primary),
          ),
          hintStyle: TextStyle(color: Colors.grey[400]),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/scan': (context) => const ScanScreen(),
        '/scan-result': (context) => const ScanResultScreen(),
        '/history': (context) => const HistoryScreen(),
        '/rewards': (context) => const RewardsScreen(),
        '/badge-collection': (context) => const BadgeCollectionScreen(),
        '/badge-details': (context) => const BadgeDetailsScreen(),
        '/points-history': (context) => const PointsHistoryScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
        '/admin-user-statistics': (context) =>
            const AdminUserStatisticsScreen(),
        '/admin-user-details': (context) => const AdminUserDetailsScreen(),
        '/admin-settings': (context) => const AdminSettingsScreen(),
      },
    );
  }
}
