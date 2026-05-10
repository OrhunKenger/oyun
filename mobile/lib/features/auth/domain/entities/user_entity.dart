class UserEntity {
  final String id;
  final String email;
  final String username;
  final int level;
  final int prestige;
  final int pixelCount;
  final int totalScore;
  final int tapPower;

  const UserEntity({
    required this.id,
    required this.email,
    required this.username,
    required this.level,
    required this.prestige,
    required this.pixelCount,
    required this.totalScore,
    required this.tapPower,
  });
}
