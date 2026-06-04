import 'package:flutter/material.dart';

/// Shared bottom navigation bar for user-facing screens.
/// Single source of truth — all 5 user screens use this.
class UserBottomNavBar extends StatelessWidget {
  final int currentIndex;
  const UserBottomNavBar({super.key, required this.currentIndex});

  static const _routes = [
    '/home',
    '/scan',
    '/history',
    '/rewards',
    '/profile',
  ];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF5CB85C),
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        if (index == currentIndex) return;
        Navigator.pushReplacementNamed(context, _routes[index]);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scan'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard), label: 'Rewards'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}

/// Shared bottom navigation bar for admin screens.
class AdminBottomNavBar extends StatelessWidget {
  final int currentIndex;
  const AdminBottomNavBar({super.key, required this.currentIndex});

  static const _routes = [
    '/admin-dashboard',
    '/admin-user-statistics',
    '/admin-settings',
  ];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF2196F3),
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        if (index == currentIndex) return;
        Navigator.pushReplacementNamed(context, _routes[index]);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }
}