class AuthResponse {
  final String accessToken;
  final String userId;
  final String username;

  AuthResponse({
    required this.accessToken,
    required this.userId,
    required this.username,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['access_token'],
        userId: json['user_id'],
        username: json['username'],
      );
}

class UserProfile {
  final String id;
  final String email;
  final String username;
  final int level;
  final int prestige;
  final int pixelCount;
  final int totalScore;
  final int tapPower;

  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.level,
    required this.prestige,
    required this.pixelCount,
    required this.totalScore,
    required this.tapPower,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'],
        email: json['email'],
        username: json['username'],
        level: json['level'],
        prestige: json['prestige'],
        pixelCount: json['pixel_count'],
        totalScore: json['total_score'],
        tapPower: json['tap_power'],
      );
}
