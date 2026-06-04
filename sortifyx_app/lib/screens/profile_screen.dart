import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/helpers.dart';
import '../widgets/bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.get('/auth/me'),
        ApiService.get('/user/stats'),
      ]);
      if (!mounted) return;
      if (results[0].statusCode == 200) {
        _user = jsonDecode(results[0].body)['user'] as Map<String, dynamic>;
      }
      if (results[1].statusCode == 200) {
        _stats = jsonDecode(results[1].body) as Map<String, dynamic>;
      }
      setState(() => _isLoading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to use the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.clearToken();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Current password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Confirm new password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (newCtrl.text.length < 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content:
                        Text('New password must be at least 6 chars')));
                return;
              }
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Passwords do not match')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final response = await ApiService.post('/auth/change-password', {
        'current_password': currentCtrl.text,
        'new_password': newCtrl.text,
      });
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Password changed'),
            backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(data['error']?.toString() ?? 'Failed'),
            backgroundColor: Colors.red));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_error!,
                              style:
                                  const TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _userCard(),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                                'Total Points',
                                '${asInt(_stats?['total_points'])}',
                                Icons.stars,
                                Colors.orange),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                                'Total Scans',
                                '${asInt(_stats?['total_scans'])}',
                                Icons.camera_alt,
                                const Color(0xFF5CB85C)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                                'Accuracy',
                                '${asDouble(_stats?['accuracy']).toStringAsFixed(0)}%',
                                Icons.check_circle,
                                Colors.blue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                                'Badges',
                                '${asInt(_stats?['earned_badges'])}',
                                Icons.military_tech,
                                Colors.purple),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _actionTile(
                          icon: Icons.lock,
                          title: 'Change Password',
                          onTap: _changePassword),
                      const SizedBox(height: 12),
                      _actionTile(
                          icon: Icons.logout,
                          title: 'Log Out',
                          iconColor: Colors.red,
                          onTap: _logout),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: const UserBottomNavBar(currentIndex: 4),
    );
  }

  Widget _userCard() {
    final username = _user?['username']?.toString() ?? '';
    final initials = username.isEmpty
        ? '?'
        : (username.length >= 2
            ? username.substring(0, 2).toUpperCase()
            : username[0].toUpperCase());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF5CB85C).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF5CB85C),
            child: Text(initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Text(username,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_user?['email']?.toString() ?? '',
              style:
                  TextStyle(fontSize: 14, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? const Color(0xFF5CB85C)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: iconColor ?? Colors.black87)),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
