import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/helpers.dart';

class AdminUserDetailsScreen extends StatefulWidget {
  const AdminUserDetailsScreen({super.key});

  @override
  State<AdminUserDetailsScreen> createState() =>
      _AdminUserDetailsScreenState();
}

class _AdminUserDetailsScreenState extends State<AdminUserDetailsScreen> {
  Map<String, dynamic>? _user;
  List<dynamic> _recentScans = [];
  int _earnedBadges = 0;
  bool _isLoading = true;
  bool _isToggling = false;
  String? _error;
  int? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_userId == null) {
      final args = ModalRoute.of(context)?.settings.arguments
          as Map<String, dynamic>?;
      _userId = asInt(args?['id']);
      _user = args; // seed UI with what we already have
      if (_userId == 0) {
        setState(() {
          _isLoading = false;
          _error = 'No user specified';
        });
      } else {
        _load();
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiService.get('/admin/users/$_userId');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _user = data['user'] as Map<String, dynamic>?;
          _recentScans = (data['recent_scans'] as List?) ?? [];
          _earnedBadges = asInt(data['earned_badges']);
          _isLoading = false;
        });
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _error = data['error']?.toString() ?? 'Failed to load';
          _isLoading = false;
        });
      }
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

  Future<void> _toggleStatus() async {
    if (_user == null || _isToggling) return;
    final wasActive = _user!['is_active'] == true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(wasActive ? 'Deactivate user?' : 'Activate user?'),
        content: Text(wasActive
            ? 'This user will not be able to log in until reactivated.'
            : 'This user will be able to log in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(wasActive ? 'Deactivate' : 'Activate')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isToggling = true);
    try {
      final response = await ApiService.put(
          '/admin/users/$_userId/toggle-status', {});
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _isToggling = false);

      if (response.statusCode == 200) {
        setState(() {
          _user = data['user'] as Map<String, dynamic>?;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['message']?.toString() ?? 'Updated'),
          backgroundColor: Colors.green,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['error']?.toString() ?? 'Failed'),
          backgroundColor: Colors.red,
        ));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isToggling = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        title: const Text('User Details'),
      ),
      body: _isLoading && _user == null
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(_error ?? 'User not found',
                        textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _userCard(),
                          const SizedBox(height: 16),
                          _statsRow(),
                          const SizedBox(height: 16),
                          _detailsCard(),
                          const SizedBox(height: 16),
                          _toggleButton(),
                          const SizedBox(height: 24),
                          const Text('Recent Scans',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (_recentScans.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text('No scans yet',
                                    style: TextStyle(
                                        color: Colors.grey[600])),
                              ),
                            )
                          else
                            ..._recentScans.map(
                                (s) => _scanRow(s as Map<String, dynamic>)),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _userCard() {
    final username = _user!['username']?.toString() ?? '';
    final initials = username.isEmpty
        ? '?'
        : (username.length >= 2
            ? username.substring(0, 2).toUpperCase()
            : username[0].toUpperCase());
    final isActive = _user!['is_active'] == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF2196F3),
            child: Text(initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Text(username,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_user!['email']?.toString() ?? '',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
              'Points',
              '${asInt(_user!['total_points'])}',
              Icons.stars,
              Colors.orange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
              'Scans',
              '${asInt(_user!['total_scans'])}',
              Icons.camera_alt,
              Colors.purple),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard('Badges', '$_earnedBadges',
              Icons.military_tech, Colors.green),
        ),
      ],
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _detailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Details',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _detailRow('User ID', '${asInt(_user!['id'])}'),
          _detailRow('Accuracy',
              '${asDouble(_user!['accuracy']).toStringAsFixed(1)}%'),
          _detailRow(
              'Joined', formatLongDate(_user!['created_at']?.toString())),
          _detailRow('Last updated',
              formatRelativeTime(_user!['updated_at']?.toString())),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey[600])),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _toggleButton() {
    final isActive = _user!['is_active'] == true;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isToggling ? null : _toggleStatus,
        icon: Icon(isActive ? Icons.block : Icons.check_circle,
            color: Colors.white),
        label: _isToggling
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(isActive ? 'Deactivate User' : 'Activate User'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Colors.red : Colors.green,
        ),
      ),
    );
  }

  Widget _scanRow(Map<String, dynamic> scan) {
    final wasteType = scan['waste_type']?.toString() ?? 'unknown';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(wasteIcon(wasteType),
              color: wasteColor(wasteType)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prettyWasteName(wasteType),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(formatRelativeTime(scan['created_at']?.toString()),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
          Text('+${asInt(scan['points_earned'])}',
              style: const TextStyle(
                  color: Color(0xFF5CB85C),
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
