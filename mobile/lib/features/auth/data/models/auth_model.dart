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
