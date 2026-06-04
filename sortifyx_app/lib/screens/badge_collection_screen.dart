import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/helpers.dart';
import '../widgets/bottom_nav.dart';

class BadgeCollectionScreen extends StatefulWidget {
  const BadgeCollectionScreen({super.key});

  @override
  State<BadgeCollectionScreen> createState() => _BadgeCollectionScreenState();
}

class _BadgeCollectionScreenState extends State<BadgeCollectionScreen> {
  List<Map<String, dynamic>> _badges = [];
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
      final response = await ApiService.get('/badges/all');
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['badges'] as List?) ?? [];
        setState(() {
          _badges = list.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _error = data['error']?.toString() ?? 'Failed to load badges';
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
    final earned = _badges.where((b) => b['earned'] == true).toList();
    final locked = _badges.where((b) => b['earned'] != true).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badge Collection'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
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
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                              'Earned (${earned.length})',
                              "Badges you've unlocked"),
                          const SizedBox(height: 16),
                          if (earned.isEmpty)
                            _emptySection(
                                'No badges yet — keep scanning!')
                          else
                            _grid(earned, isLocked: false),
                          const SizedBox(height: 32),
                          _sectionHeader('Locked (${locked.length})',
                              'Keep going to unlock'),
                          const SizedBox(height: 16),
                          if (locked.isEmpty)
                            _emptySection(
                                'All badges earned. Amazing!')
                          else
                            _grid(locked, isLocked: true),
                        ],
                      ),
                    ),
                  ),
                ),
      bottomNavigationBar: const UserBottomNavBar(currentIndex: 3),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }

  Widget _emptySection(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(text, style: TextStyle(color: Colors.grey[600])),
      ),
    );
  }

  Widget _grid(List<Map<String, dynamic>> items,
      {required bool isLocked}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final badge = items[i];
        return GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            '/badge-details',
            arguments: {'badge_id': badge['id']},
          ),
          child: _badgeTile(badge, isLocked: isLocked),
        );
      },
    );
  }

  Widget _badgeTile(Map<String, dynamic> badge, {required bool isLocked}) {
    final color = isLocked ? Colors.grey : const Color(0xFF5CB85C);
    return Column(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundColor:
              isLocked ? Colors.grey[200] : color.withOpacity(0.1),
          child: Icon(
            iconFromName(badge['icon']?.toString() ?? ''),
            size: 35,
            color: isLocked ? Colors.grey[400] : color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          badge['name']?.toString() ?? '',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isLocked ? Colors.grey : Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${asInt(badge['points_required'])} pts',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
