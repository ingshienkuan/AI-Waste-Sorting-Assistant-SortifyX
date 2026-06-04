import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/helpers.dart';

class BadgeDetailsScreen extends StatefulWidget {
  const BadgeDetailsScreen({super.key});

  @override
  State<BadgeDetailsScreen> createState() => _BadgeDetailsScreenState();
}

class _BadgeDetailsScreenState extends State<BadgeDetailsScreen> {
  Map<String, dynamic>? _badge;
  bool _isLoading = true;
  String? _error;
  int? _badgeId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_badgeId == null) {
      final args = ModalRoute.of(context)?.settings.arguments
          as Map<String, dynamic>?;
      _badgeId = args?['badge_id'] as int?;
      if (_badgeId == null) {
        setState(() {
          _isLoading = false;
          _error = 'No badge specified';
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
      final response = await ApiService.get('/badges/$_badgeId');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _badge = data['badge'] as Map<String, dynamic>?;
          _isLoading = false;
        });
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _error = data['error']?.toString() ?? 'Failed to load badge';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Badge Details')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ),
                )
              : _badge == null
                  ? const Center(child: Text('Badge not found'))
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final badge = _badge!;
    final earned = badge['earned'] == true;
    final color = earned ? const Color(0xFF5CB85C) : Colors.grey;
    final progress = badge['progress'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: earned
                        ? color.withOpacity(0.1)
                        : Colors.grey[200],
                    child: Icon(
                      iconFromName(badge['icon']?.toString() ?? ''),
                      size: 60,
                      color: earned ? color : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    badge['name']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: earned ? color : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: earned
                          ? color.withOpacity(0.1)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      earned ? 'EARNED' : 'LOCKED',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: earned ? color : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Description',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              badge['description']?.toString() ?? '',
              style:
                  TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            const Text('Requirements',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _requirementRow(
              icon: Icons.stars,
              label: 'Points',
              value: '${asInt(badge['points_required'])}',
            ),
            const SizedBox(height: 8),
            _requirementRow(
              icon: Icons.camera_alt,
              label: 'Scans',
              value: '${asInt(badge['scans_required'])}',
            ),
            const SizedBox(height: 24),
            if (earned) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF5CB85C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF5CB85C)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Earned on',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          Text(
                            formatLongDate(
                                badge['earned_at']?.toString()),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (progress != null) ...[
              const Text('Your Progress',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _progressBar(
                label: 'Points',
                percent: asDouble(progress['points']),
                detail:
                    '${asInt(progress['points_needed'])} more needed',
              ),
              const SizedBox(height: 16),
              _progressBar(
                label: 'Scans',
                percent: asDouble(progress['scans']),
                detail:
                    '${asInt(progress['scans_needed'])} more needed',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _requirementRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF5CB85C)),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Text(label, style: const TextStyle(fontSize: 14))),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _progressBar({
    required String label,
    required double percent,
    required String detail,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            Text('${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF5CB85C)),
          ),
        ),
        const SizedBox(height: 4),
        Text(detail,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
