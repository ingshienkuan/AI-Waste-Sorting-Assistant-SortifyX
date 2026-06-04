class UserModel {
  final int id;
  final String username;
  final String email;
  final bool isAdmin;
  final bool isActive;
  final int totalPoints;
  final int totalScans;
  final double accuracy;
  final String createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.isAdmin,
    required this.isActive,
    required this.totalPoints,
    required this.totalScans,
    required this.accuracy,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      isAdmin: json['is_admin'] ?? false,
      isActive: json['is_active'] ?? true,
      totalPoints: json['total_points'] ?? 0,
      totalScans: json['total_scans'] ?? 0,
      accuracy: (json['accuracy'] ?? 0.0).toDouble(),
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'is_admin': isAdmin,
      'is_active': isActive,
      'total_points': totalPoints,
      'total_scans': totalScans,
      'accuracy': accuracy,
      'created_at': createdAt,
    };
  }
}
