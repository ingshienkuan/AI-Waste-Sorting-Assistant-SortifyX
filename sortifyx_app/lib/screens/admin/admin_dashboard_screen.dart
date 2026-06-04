import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/bottom_nav.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  List<dynamic> _recentUsers = [];
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
        ApiService.get('/admin/dashboard'),
        ApiService.get('/admin/users', query: {'per_page': 3}),
      ]);
      if (!mounted) return;
      if (results[0].statusCode == 200) {
        _stats = jsonDecode(results[0].body) as Map<String, dynamic>;
      }
      if (results[1].statusCode == 200) {
        _recentUsers =
            (jsonDecode(results[1].body)['users'] as List?) ?? [];
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
    await ApiService.clearToken();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        title: const Text('Admin Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const Text('Overview',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              icon: Icons.people,
                              color: Colors.blue,
                              label: 'Total Users',
                              value: '${asInt(_stats?['total_users'])}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metric(
                              icon: Icons.person,
                              color: Colors.green,
                              label: 'Active',
                              value:
                                  '${asInt(_stats?['active_users'])}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              icon: Icons.camera_alt,
                              color: Colors.purple,
                              label: 'Total Scans',
                              value:
                                  '${asInt(_stats?['total_scans'])}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metric(
                              icon: Icons.today,
                              color: Colors.orange,
                              label: 'Scans Today',
                              value:
                                  '${asInt(_stats?['scans_today'])}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              icon: Icons.check_circle,
                              color: Colors.teal,
                              label: 'Avg Accuracy',
                              value:
                                  '${asDouble(_stats?['accuracy']).toStringAsFixed(0)}%',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metric(
                              icon: Icons.trending_up,
                              color: Colors.pink,
                              label: 'Growth',
                              value:
                                  '${asDouble(_stats?['growth_percentage']).toStringAsFixed(0)}%',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Recent Users',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(
                                context, '/admin-user-statistics'),
                            child: const Text('See All →',
                                style: TextStyle(
                                    color: Color(0xFF2196F3),
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_recentUsers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('No users yet',
                                style: TextStyle(
                                    color: Colors.grey[600])),
                          ),
                        )
                      else
                        ..._recentUsers.map(
                            (u) => _userTile(u as Map<String, dynamic>)),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: const AdminBottomNavBar(currentIndex: 0),
    );
  }

  Widget _metric({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> u) {
    final username = u['username']?.toString() ?? '';
    final initials = username.isEmpty
        ? '?'
        : (username.length >= 2
            ? username.substring(0, 2).toUpperCase()
            : username[0].toUpperCase());
    final isActive = u['is_active'] == true;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/admin-user-details',
        arguments: u,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF2196F3),
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(username,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(u['email']?.toString() ?? '',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 10,
                  color: isActive
                      ? Colors.green[700]
                      : Colors.red[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
