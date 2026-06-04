import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../widgets/bottom_nav.dart';

class AdminUserStatisticsScreen extends StatefulWidget {
  const AdminUserStatisticsScreen({Key? key}) : super(key: key);

  @override
  State<AdminUserStatisticsScreen> createState() =>
      _AdminUserStatisticsScreenState();
}

class _AdminUserStatisticsScreenState extends State<AdminUserStatisticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load user statistics
      final statsResponse = await ApiService.get('/admin/statistics/users');

      // Load users list
      final usersResponse =
          await ApiService.get('/admin/users?page=1&per_page=50');

      if (statsResponse.statusCode == 200 && usersResponse.statusCode == 200) {
        final statsData = jsonDecode(statsResponse.body);
        final usersData = jsonDecode(usersResponse.body);

        setState(() {
          _stats = statsData;
          _users = usersData['users'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        title: const Text('Users'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview Stats
                      const Text(
                        'Overview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Users',
                              '${_stats?['total_users'] ?? 0}',
                              Icons.people,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Active Users',
                              '${_stats?['active_users'] ?? 0}',
                              Icons.check_circle,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Inactive Users',
                              '${_stats?['inactive_users'] ?? 0}',
                              Icons.cancel,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Verified Users',
                              '${_stats?['verified_users'] ?? 0}',
                              Icons.verified,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Weekly Chart Placeholder
                      const Text(
                        'Weekly Registrations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildWeeklyChart(),
                      ),

                      const SizedBox(height: 32),

                      // All Users List
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'All Users',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_users.length} users',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // User List
                      if (_users.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'No users found',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _users.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return _buildUserCard(user);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: const AdminBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildWeeklyChart() {
    final data = (_stats?['weekly_registrations'] as List?) ?? [];
    if (data.isEmpty) {
      return Center(
        child: Text('No data available',
            style: TextStyle(color: Colors.grey[600])),
      );
    }
    // Find max for scaling (min 1 to avoid /0)
    int maxCount = 1;
    for (final d in data) {
      final c = (d['count'] as num?)?.toInt() ?? 0;
      if (c > maxCount) maxCount = c;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: data.map<Widget>((d) {
        final day = d['day']?.toString() ?? '';
        final count = (d['count'] as num?)?.toInt() ?? 0;
        final ratio = count / maxCount;
        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('$count',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 120 * ratio,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 6),
              Text(day,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[700])),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final username = user['username'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final isActive = user['is_active'] ?? false;
    final totalPoints = user['total_points'] ?? 0;
    final totalScans = user['total_scans'] ?? 0;

    final initials = username.length >= 2
        ? username.substring(0, 2).toUpperCase()
        : username.toUpperCase();

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/admin-user-details',
          arguments: user,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalPoints pts • $totalScans scans',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? Colors.green[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: isActive ? Colors.green : Colors.grey,
                  fontSize: 12,
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
