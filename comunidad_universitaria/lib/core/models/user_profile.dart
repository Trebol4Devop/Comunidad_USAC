class UserProfile {
  final String userId;
  final String alias;
  final String role; // 'student', 'moderator', 'admin'
  final String facultadId;
  final String carreraId;
  final String sedeId;
  final String bio;
  final int avatarColorIndex;
  final int avatarIconIndex;
  final String? contactWhatsapp;
  final String? contactTelegram;
  final String? contactInstagram;
  final String? email;

  const UserProfile({
    required this.userId,
    required this.alias,
    this.role = 'student',
    this.facultadId = '08',
    this.carreraId = 'sistemas',
    this.sedeId = 'central',
    this.bio = '',
    this.avatarColorIndex = 0,
    this.avatarIconIndex = 0,
    this.contactWhatsapp,
    this.contactTelegram,
    this.contactInstagram,
    this.email,
  });

  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderator' || role == 'admin';

  UserProfile copyWith({
    String? userId,
    String? alias,
    String? role,
    String? facultadId,
    String? carreraId,
    String? sedeId,
    String? bio,
    int? avatarColorIndex,
    int? avatarIconIndex,
    String? contactWhatsapp,
    String? contactTelegram,
    String? contactInstagram,
    String? email,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      alias: alias ?? this.alias,
      role: role ?? this.role,
      facultadId: facultadId ?? this.facultadId,
      carreraId: carreraId ?? this.carreraId,
      sedeId: sedeId ?? this.sedeId,
      bio: bio ?? this.bio,
      avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
      avatarIconIndex: avatarIconIndex ?? this.avatarIconIndex,
      contactWhatsapp: contactWhatsapp ?? this.contactWhatsapp,
      contactTelegram: contactTelegram ?? this.contactTelegram,
      contactInstagram: contactInstagram ?? this.contactInstagram,
      email: email ?? this.email,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'alias': alias,
      'role': role,
      'facultad_id': facultadId,
      'carrera_id': carreraId,
      'sede_id': sedeId,
      'bio': bio,
      'avatar_color_index': avatarColorIndex,
      'avatar_icon_index': avatarIconIndex,
      'contact_whatsapp': contactWhatsapp,
      'contact_telegram': contactTelegram,
      'contact_instagram': contactInstagram,
      'email': email,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['user_id']?.toString() ?? '',
      alias: map['alias']?.toString() ?? 'Estudiante USAC',
      role: map['role']?.toString() ?? 'student',
      facultadId: map['facultad_id']?.toString() ?? '08',
      carreraId: map['carrera_id']?.toString() ?? 'sistemas',
      sedeId: map['sede_id']?.toString() ?? 'central',
      bio: map['bio']?.toString() ?? '',
      avatarColorIndex: map['avatar_color_index'] is int ? map['avatar_color_index'] as int : 0,
      avatarIconIndex: map['avatar_icon_index'] is int ? map['avatar_icon_index'] as int : 0,
      contactWhatsapp: map['contact_whatsapp']?.toString(),
      contactTelegram: map['contact_telegram']?.toString(),
      contactInstagram: map['contact_instagram']?.toString(),
      email: map['email']?.toString(),
    );
  }
}
