class UserProfile {
  final String userId;
  final String alias;
  final String role; // 'student', 'moderator', 'admin'
  final String facultadId;
  final String carreraId;

  const UserProfile({
    required this.userId,
    required this.alias,
    this.role = 'student',
    this.facultadId = '08',
    this.carreraId = 'sistemas',
  });

  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderator' || role == 'admin';
}
