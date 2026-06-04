import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/helpers.dart';
import '../widgets/bottom_nav.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  Map<String, dynamic>? _summary;
  List<dynamic> _earnedBadges = [];
  List<dynamic> _rewards = [];
  bool _isLoading = true;
  bool _isRedeeming = false;
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
        ApiService.get('/rewards/summary'),
        ApiService.get('/badges/earned'),
        ApiService.get('/rewards/available'),
      ]);
      if (!mounted) return;
      if (results[0].statusCode == 200) {
        _summary = jsonDecode(results[0].body) as Map<String, dynamic>;
      }
      if (results[1].statusCode == 200) {
        _earnedBadges =
            (jsonDecode(results[1].body)['badges'] as List?) ?? [];
      }
      if (results[2].statusCode == 200) {
        _rewards =
            (jsonDecode(results[2].body)['rewards'] as List?) ?? [];
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

  Future<void> _redeem(Map<String, dynamic> reward) async {
    final cost = asInt(reward['points_required']);
    final balance = asInt(_summary?['total_points']);
    if (balance < cost) {
      _toast('Not enough points (you have $balance, need $cost)',
          isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redeem reward?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reward['name']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(reward['description']?.toString() ?? ''),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.stars,
                    size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  '$cost points',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Redeem')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRedeeming = true);
    try {
      final response = await ApiService.post('/rewards/redeem', {
        'points': cost,
        'reward_name': reward['name'],
      });
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _isRedeeming = false);

      if (response.statusCode == 200) {
        _toast('Redeemed! Check your email/account for the reward.');
        await _loadAll();
      } else {
        _toast(data['error']?.toString() ?? 'Redemption failed',
            isError: true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isRedeeming = false);
      _toast(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRedeeming = false);
      _toast('Unexpected error: $e', isError: true);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  IconData _rewardIcon(String? name) {
    switch (name) {
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'local_taxi':
        return Icons.local_taxi;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'water_drop':
        return Icons.water_drop;
      case 'shopping_basket':
        return Icons.shopping_basket;
      case 'park':
        return Icons.park;
      default:
        return Icons.redeem;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
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
                              child: Text(_error!,
                                  style:
                                      const TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _totalPointsCard(),
                          const SizedBox(height: 24),
                          const Text(
                            'Redeem Points',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Use your earned points for real rewards',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          if (_rewards.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  'No rewards available right now',
                                  style: TextStyle(
                                      color: Colors.grey[600]),
                                ),
                              ),
                            )
                          else
                            ..._rewards.map(
                              (r) => _rewardCard(
                                  r as Map<String, dynamic>),
                            ),
                          const SizedBox(height: 32),
                          Text(
                            'My Badges (${_earnedBadges.length})',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 100,
                            child: _earnedBadges.isEmpty
                                ? Center(
                                    child: Text(
                                      'No badges yet — keep scanning!',
                                      style: TextStyle(
                                          color: Colors.grey[600]),
                                    ),
                                  )
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _earnedBadges.length,
                                    itemBuilder: (_, i) {
                                      final ub = _earnedBadges[i]
                                          as Map<String, dynamic>;
                                      final badge = ub['badge']
                                          as Map<String, dynamic>?;
                                      if (badge == null) {
                                        return const SizedBox.shrink();
                                      }
                                      return _badgePill(badge);
                                    },
                                  ),
                          ),
                          const SizedBox(height: 24),
                          _navTile(
                            icon: Icons.bar_chart,
                            iconColor: Colors.orange,
                            iconBg: Colors.orange[50]!,
                            title: 'Points History',
                            subtitle: 'View all transactions',
                            onTap: () => Navigator.pushNamed(
                                context, '/points-history'),
                          ),
                          const SizedBox(height: 12),
                          _navTile(
                            icon: Icons.military_tech,
                            iconColor: Colors.purple,
                            iconBg: Colors.purple[50]!,
                            title: 'All Badges',
                            subtitle:
                                '${asInt(_summary?['total_badges'])} badges available',
                            onTap: () => Navigator.pushNamed(
                                context, '/badge-collection'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          if (_isRedeeming)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF5CB85C)),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const UserBottomNavBar(currentIndex: 3),
    );
  }

  Widget _totalPointsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF5CB85C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Total Points',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            '${asInt(_summary?['total_points'])}',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep scanning to earn more!',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _rewardCard(Map<String, dynamic> reward) {
    final cost = asInt(reward['points_required']);
    final balance = asInt(_summary?['total_points']);
    final affordable = balance >= cost;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: affordable
                  ? const Color(0xFF5CB85C).withOpacity(0.12)
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _rewardIcon(reward['icon']?.toString()),
              color: affordable
                  ? const Color(0xFF5CB85C)
                  : Colors.grey[500],
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward['name']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  reward['description']?.toString() ?? '',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.stars,
                        size: 14,
                        color: affordable
                            ? Colors.orange
                            : Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '$cost pts',
                      style: TextStyle(
                        fontSize: 12,
                        color: affordable
                            ? Colors.orange
                            : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: affordable ? () => _redeem(reward) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5CB85C),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(affordable ? 'Redeem' : 'Locked'),
          ),
        ],
      ),
    );
  }

  Widget _badgePill(Map<String, dynamic> badge) {
    final name = badge['name']?.toString() ?? 'Badge';
    final iconName = badge['icon']?.toString() ?? '';
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/badge-details',
        arguments: {'badge_id': badge['id']},
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor:
                  const Color(0xFF5CB85C).withOpacity(0.1),
              child: Icon(
                iconFromName(iconName),
                size: 30,
                color: const Color(0xFF5CB85C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}