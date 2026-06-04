import 'package:flutter/material.dart';

import '../utils/helpers.dart';

class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?;
    if (args == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('No scan data available')),
      );
    }

    final scan = args['scan'] as Map<String, dynamic>?;
    final detection = args['detection'] as Map<String, dynamic>?;
    final disposalTips = args['disposal_tips'] as Map<String, dynamic>?;
    final userStats = args['user_stats'] as Map<String, dynamic>?;
    final awardedBadges = (args['awarded_badges'] as List?) ?? const [];

    if (scan == null || detection == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Invalid scan data')),
      );
    }

    final wasteType =
        (detection['waste_type'] ?? 'Unknown').toString().toUpperCase();
    final confidence = (asDouble(detection['confidence']) * 100).toInt();
    final pointsEarned = asInt(scan['points_earned']);
    final tips = (disposalTips?['tips'] as List?) ?? const [];
    final isSimulated = detection['simulated'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Icon(Icons.check_circle,
                  color: Color(0xFF5CB85C), size: 60),
              const SizedBox(height: 24),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: wasteColor(wasteType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  wasteIcon(wasteType),
                  size: 50,
                  color: wasteColor(wasteType),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                wasteType,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5CB85C),
                ),
              ),
              if (isSimulated)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '(simulated — model not loaded)',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 24),
              _infoCard(
                'Confidence: $confidence%',
                color: const Color(0xFF5CB85C).withOpacity(0.1),
              ),
              const SizedBox(height: 12),
              _infoCard(
                'Points Earned: +$pointsEarned',
                color: Colors.orange[50]!,
                textColor: Colors.orange,
                bold: true,
              ),
              if (awardedBadges.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎉 New Badge Unlocked!',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.purple,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ...awardedBadges.map((badge) {
                        final m = badge as Map<String, dynamic>;
                        return Text(
                          '${m['name']} (+${asInt(m['points_required'])} pts)',
                          style: const TextStyle(fontSize: 12),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (tips.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Disposal Tips:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...tips.map((tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check,
                                    size: 18, color: Color(0xFF5CB85C)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tip.toString(),
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700]),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              if (userStats != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Your Stats',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _stat('Total Points',
                              '${asInt(userStats['total_points'])}'),
                          _stat('Total Scans',
                              '${asInt(userStats['total_scans'])}'),
                          _stat('Accuracy',
                              '${asDouble(userStats['accuracy']).toStringAsFixed(0)}%'),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/scan'),
                  child: const Text(
                    'Scan Again',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (r) => false),
                  child: const Text(
                    'Back to Home',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(String text,
      {required Color color, Color? textColor, bool bold = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: textColor ?? Colors.grey[700],
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5CB85C),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
