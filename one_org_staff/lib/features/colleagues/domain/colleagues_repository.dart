/// One entry in the staff directory.
///
/// Mirrors the user shape from `docs/staff/users.md` — the same `GET /users`
/// response the web app's Colleagues page reads.
class Colleague {
  const Colleague({
    required this.id,
    required this.fullName,
    this.username,
    this.phoneNumber,
    this.email,
    this.pictureUrl,
    this.status,
    this.roles = const [],
  });

  final int id;
  final String fullName;
  final String? username;
  final String? phoneNumber;
  final String? email;
  final String? pictureUrl;
  final String? status;
  final List<String> roles;

  /// What the row shows. Falls back through username so a user with no
  /// `full_name` still appears rather than rendering as a blank row.
  String get displayName {
    if (fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    final name = username?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Unnamed';
  }

  bool get isActive => status?.toLowerCase() == 'active';

  /// Up to two initials for the avatar placeholder.
  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  /// The letter this colleague is filed under in the A–Z list.
  String get sortLetter {
    final name = displayName;
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  /// The number with formatting stripped — dialers and SMS apps choke on the
  /// spaces the API returns, so everything but digits and a leading `+` goes.
  String? get _cleanNumber {
    final phone = phoneNumber?.trim();
    if (phone == null || phone.isEmpty) {
      return null;
    }
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned.isEmpty ? null : cleaned;
  }

  /// `tel:` target for the call button.
  String? get dialUri {
    final number = _cleanNumber;
    return number == null ? null : 'tel:$number';
  }

  /// `sms:` target for the message button.
  String? get smsUri {
    final number = _cleanNumber;
    return number == null ? null : 'sms:$number';
  }

  /// True when [term] appears in the name, username, phone or email — the same
  /// four fields the web page searches.
  bool matches(String term) {
    final needle = term.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    for (final field in [fullName, username, phoneNumber, email]) {
      if (field != null && field.toLowerCase().contains(needle)) {
        return true;
      }
    }
    return false;
  }

  factory Colleague.fromJson(Map<String, dynamic> json) {
    return Colleague(
      id: _asInt(json['id']) ?? -1,
      fullName: _asString(json['full_name'] ?? json['fullName']) ?? '',
      username: _asString(json['username']),
      phoneNumber: _asString(json['phone_number'] ?? json['phoneNumber']),
      email: _asString(json['email']),
      // Same field the profile parser reads — see docs/staff/users.md.
      pictureUrl: _asString(json['picture_url'] ?? json['pictureUrl']),
      status: _asString(json['status']),
      roles: _asRoles(json['roles']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _asString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  static List<String> _asRoles(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const [];
  }
}

abstract class ColleaguesRepository {
  /// Every user the caller may see. Filtering to active staff and sorting is
  /// the page's job, so the repository stays a thin read of the endpoint.
  Future<List<Colleague>> getColleagues(String token);
}
