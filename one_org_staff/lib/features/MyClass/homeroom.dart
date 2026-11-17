import '../MyLessons/lesson_points_repository.dart';
import '../auth/domain/auth_repository.dart';

/// The class this person is homeroom teacher of, if any.
GroupEntry? homeroomOf(List<GroupEntry> groups, AppUserProfile? profile) {
  if (profile == null) return null;
  final name = profile.fullName.trim().toLowerCase();
  return groups
      .where(
        (group) =>
            group.teacherIds.contains(profile.id) ||
            group.teacherName?.trim().toLowerCase() == name,
      )
      .firstOrNull;
}
