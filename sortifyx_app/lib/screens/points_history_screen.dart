import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/helpers.dart';

class PointsHistoryScreen extends StatefulWidget {
  const PointsHistoryScreen({super.key});

  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> {
  String _filter = 'all'; // 'all' | 'earned' | 'spent'
  List<dynamic> _transactions = [];
  int _totalEarned = 0;
  int _totalSpent = 0;
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
      final response = await ApiService.get(
        '/user/points/history',
        query: {'type': _filter, 'per_page': 100},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _transactions = (data['transactions'] as List?) ?? [];
          _totalEarned = asInt(data['total_earned']);
          _totalSpent = asInt(data['total_spent']);
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

  void _setFilter(String f) {
    if (_filter == f) return;
    setState(() => _filter = f);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Points History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _summaryCard(
                    title: 'Earned',
                    value: '+$_totalEarned',
                    color: const Color(0xFF5CB85C),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(
                    title: 'Spent',
                    value: '-$_totalSpent',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _tab('All', 'all')),
                Expanded(child: _tab('Earned', 'earned')),
                Expanded(child: _tab('Spent', 'spent')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _summaryCard(
      {required String title,
      required String value,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _tab(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => _setFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? const Color(0xFF5CB85C)
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? const Color(0xFF5CB85C)
                : Colors.grey[600],
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No transactions',
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final t = _transactions[i] as Map<String, dynamic>;
          final points = asInt(t['points']);
          final positive = points >= 0;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: positive
                        ? const Color(0xFF5CB85C).withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    positive ? Icons.add : Icons.remove,
                    color: positive
                        ? const Color(0xFF5CB85C)
                        : Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['description']?.toString() ?? 'Transaction',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatRelativeTime(
                            t['created_at']?.toString()),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${positive ? '+' : ''}$points',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: positive
                        ? const Color(0xFF5CB85C)
                        : Colors.orange,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
