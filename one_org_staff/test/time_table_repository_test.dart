import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/features/TimeTable/time_table_repository.dart';

void main() {
  test('parses subject id from timetable json', () {
    final lesson = TimetableLesson.fromJson({
      'id': 10,
      'lesson_type': 'structured',
      'group_id': 5,
      'subject_id': 3,
      'subject': 'Math',
      'time_id': 2,
    });

    expect(lesson.groupId, 5);
    expect(lesson.subjectId, 3);
    expect(lesson.title, 'Math');
  });
}
