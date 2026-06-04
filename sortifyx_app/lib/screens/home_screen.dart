import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/helpers.dart';
import '../widgets/bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _stats;
  String? _username;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.get('/user/stats'),
        ApiService.get('/auth/me'),
      ]);
      if (!mounted) return;
      if (results[0].statusCode == 200) {
        _stats = jsonDecode(results[0].body) as Map<String, dynamic>;
      }
      if (results[1].statusCode == 200) {
        final user = jsonDecode(results[1].body)['user'] as Map<String, dynamic>;
        _username = user['username']?.toString();
      }
      setState(() => _isLoading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.home, size: 20),
            SizedBox(width: 8),
            Text('Home'),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
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
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          Text(
                            'Hello${_username == null ? '' : ', $_username'}!',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('👋', style: TextStyle(fontSize: 24)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Let's sort waste today",
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      // Points card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF5CB85C).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Your Points',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${asInt(_stats?['total_points'])}',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5CB85C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Scan button
                      Center(
                        child: GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/scan'),
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: const BoxDecoration(
                              color: Color(0xFF5CB85C),
                              shape: BoxShape.circle,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.camera_alt,
                                    size: 50, color: Colors.white),
                                SizedBox(height: 8),
                                Text(
                                  'SCAN',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Stats row
                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              '${asInt(_stats?['total_scans'])}',
                              'Total Scans',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _statCard(
                              '${asDouble(_stats?['accuracy']).toStringAsFixed(0)}%',
                              'Accuracy',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Today's scans
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Scans Today',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${asInt(_stats?['scans_today'])}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: const UserBottomNavBar(currentIndex: 0),
    );
  }

  Widget _statCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
