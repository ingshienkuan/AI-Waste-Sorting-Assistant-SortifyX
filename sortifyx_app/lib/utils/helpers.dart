import 'package:flutter/material.dart';

/// Map a waste type string to a Material icon.
IconData wasteIcon(String wasteType) {
  switch (wasteType.toLowerCase().replaceAll('-', '_')) {
    case 'plastic':
      return Icons.water_drop;
    case 'metal':
      return Icons.local_drink;
    case 'glass':
      return Icons.wine_bar;
    case 'paper':
      return Icons.article;
    case 'organic':
      return Icons.eco;
    case 'cardboard':
      return Icons.inventory_2;
    case 'non_recyclable':
    case 'trash':
      return Icons.delete;
    case 'battery':
      return Icons.battery_charging_full;
    case 'electronics':
      return Icons.devices;
    default:
      return Icons.help_outline;
  }
}

/// Map a waste type string to a colour for visual grouping.
Color wasteColor(String wasteType) {
  switch (wasteType.toLowerCase().replaceAll('-', '_')) {
    case 'plastic':
      return Colors.pink;
    case 'metal':
      return Colors.orange;
    case 'glass':
      return Colors.green;
    case 'paper':
      return Colors.grey;
    case 'organic':
      return Colors.amber;
    case 'cardboard':
      return Colors.brown;
    case 'non_recyclable':
    case 'trash':
      return Colors.black54;
    case 'battery':
      return Colors.red;
    case 'electronics':
      return Colors.blue;
    default:
      return Colors.blueGrey;
  }
}

/// Map a Material icon name (sent by the backend) to an actual IconData.
IconData iconFromName(String name) {
  switch (name) {
    case 'energy_savings_leaf':
      return Icons.energy_savings_leaf;
    case 'recycling':
      return Icons.recycling;
    case 'public':
      return Icons.public;
    case 'volunteer_activism':
      return Icons.volunteer_activism;
    case 'workspace_premium':
      return Icons.workspace_premium;
    case 'star':
      return Icons.star;
    case 'emoji_events':
      return Icons.emoji_events;
    default:
      return Icons.military_tech;
  }
}

/// Safely coerce a JSON value to a double (handles int / num / null / string).
double asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

/// Safely coerce a JSON value to an int.
int asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

/// Human-readable relative time, e.g. "5m ago", "Yesterday, 11:15 AM".
/// Accepts an ISO 8601 string (the format the backend emits).
String formatRelativeTime(String? isoString) {
  if (isoString == null || isoString.isEmpty) return '';
  DateTime dt;
  try {
    dt = DateTime.parse(isoString).toLocal();
  } catch (_) {
    return isoString;
  }
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';

  final today = DateTime(now.year, now.month, now.day);
  final scanDay = DateTime(dt.year, dt.month, dt.day);
  final dayDiff = today.difference(scanDay).inDays;

  final timeStr = _formatTime(dt);
  if (dayDiff == 0) return 'Today, $timeStr';
  if (dayDiff == 1) return 'Yesterday, $timeStr';
  if (dayDiff < 7) return '$dayDiff days ago';
  return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
}

String _formatTime(DateTime dt) {
  final h = dt.hour == 0
      ? 12
      : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final m = _pad(dt.minute);
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ampm';
}

String _pad(int n) => n.toString().padLeft(2, '0');

/// Display date like "January 15, 2025"
String formatLongDate(String? isoString) {
  if (isoString == null || isoString.isEmpty) return '';
  DateTime dt;
  try {
    dt = DateTime.parse(isoString).toLocal();
  } catch (_) {
    return isoString;
  }
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

/// Human-friendly title for a waste type, e.g. "Plastic Scan".
String prettyWasteName(String? wasteType) {
  if (wasteType == null || wasteType.isEmpty) return 'Item';
  return wasteType
      .toLowerCase()
      .split(RegExp(r'[_\-]'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}