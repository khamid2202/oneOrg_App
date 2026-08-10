class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppUserProfile {
  const AppUserProfile({
    required this.id,
    required this.fullName,
    required this.subtitle,
    required this.email,
    required this.phone,
    required this.department,
    required this.joinedDate,
    this.profileImageUrl,
  });

  final int id;
  final String fullName;
  final String subtitle;
  final String email;
  final String phone;
  final String department;
  final String joinedDate;
  final String? profileImageUrl;

  factory AppUserProfile.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id'] ?? json['userId'] ?? json['user_id'] ?? json['teacher_id'] ?? json['teacherId']) ?? 0;
    final role = _firstString(json, const [
      'role',
      'position',
      'title',
      'job_title',
      'jobTitle',
    ]);
    final department =
            _firstString(json, const ['department', 'department_name']) ??
        _nestedString(json['department']) ??
        _nestedString(json['group']) ??
        'Not specified';
    final firstName =
        _firstString(json, const ['first_name', 'firstName']) ?? '';
    final lastName = _firstString(json, const ['last_name', 'lastName']) ?? '';
    final combinedName = [firstName, lastName]
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    final fullName =
            _firstString(json, const ['full_name', 'fullName', 'name']) ??
        (combinedName.isNotEmpty ? combinedName : null) ??
        _firstString(json, const ['username', 'email']) ??
        'OneOrg Staff User';
    final subtitleParts = [role, department]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty && part != 'Not specified')
        .toList();

    return AppUserProfile(
      id: id,
      fullName: fullName,
      subtitle:
          subtitleParts.isEmpty ? 'Staff member' : subtitleParts.join(' • '),
      email: _firstString(json, const ['email']) ?? 'Not specified',
      phone: _firstString(json, const [
            'phone',
            'phone_number',
            'phoneNumber',
            'mobile',
          ]) ??
          'Not specified',
      department: department,
      joinedDate: _formatDate(
        _firstString(json, const [
              'joined_at',
              'joinedAt',
              'created_at',
              'createdAt',
            ]) ??
            'Not specified',
      ),
      profileImageUrl: _firstString(json, const [
        'avatar',
        'avatar_url',
        'avatarUrl',
        'photo',
        'photo_url',
        'photoUrl',
        'profile_image',
        'profileImage',
        'image',
        'image_url',
        'imageUrl',
      ]),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String? _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      final nested = _nestedString(value);
      if (nested != null) {
        return nested;
      }
    }
    return null;
  }

  static String? _nestedString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    if (value is Map<String, dynamic>) {
      for (final key in const ['name', 'title', 'label', 'value']) {
        final nestedValue = value[key];
        if (nestedValue is String && nestedValue.trim().isNotEmpty) {
          return nestedValue.trim();
        }
      }
    }

    return null;
  }

  static String _formatDate(String rawValue) {
    final parsedDate = DateTime.tryParse(rawValue);
    if (parsedDate == null) {
      return rawValue;
    }

    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${parsedDate.day.toString().padLeft(2, '0')} ${monthNames[parsedDate.month - 1]} ${parsedDate.year}';
  }
}

abstract class AuthRepository {
  Future<String> signIn({
    required String username,
    required String password,
  });

  Future<String> updatePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
  });

  Future<void> validate(String token);

  Future<void> revoke(String token);

  Future<AppUserProfile> getCurrentUser(String token);
}