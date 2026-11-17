# Lesson Instances API (teaching day)

**Base path:** `/lesson-instances`

Only lessons (their class's branch) at the branches selected by `X-Branch-Id` are visible; see
[Branches](branches.md#scoped-data).

## Overview
A lesson instance is one real lesson on a date, expanded from the **published**
[timetable version](timetables.md). Attendance, the class register topic and
homework attach to it.

**How instances are kept in sync.** The following re-sync
today → +14 days:
- a nightly job (02:30);
- app start;
- publishing a version (from its `valid_from`);
- any create, update, delete or upload on the published version's entries.

For past dates, or dates further ahead, use `POST /lesson-instances/generate`.
Requesting a teacher's day with no instances yet also generates that day.

**Rules of a sync:**
- One instance per structured (non-text) entry per matching weekday.
- Only inside the academic year's `start_date..end_date` and the version's
  `valid_from..valid_to`.
- [Holidays](holidays.md) are skipped.
- Class, subject, teachers, room and times are **snapshots** refreshed on each
  sync, so history survives later timetable changes.
- A scheduled instance that is no longer in the timetable is deleted. If it
  already has attendance, grades, a topic or homework, it's kept with status
  `cancelled` and `cancel_reason: "Removed from the timetable"`. Records are
  never lost.

**Who can write.** Attendance, grades, topics and homework can be written only by the
lesson's primary teacher, an additional teacher, or its substitute teacher
([Substitutions](substitutions.md)). Users with `lesson_instances.manage`
(admin by default) can write for any lesson. Cancelled lessons are read-only (`409`).

Permissions:
- `lesson_instances.read`: list and detail.
- `lesson_instances.update`: attendance and topics (plus the ownership rule above).
- `lesson_instances.create`: generate.
- Teachers get `read` and `update` by default.

### Choice lessons
A choice option is one lesson across classes, so it gets one instance, created from
its canonical timetable row: the row with the lowest group id. Its `group_id` is
only that class, so use `group_ids` for the classes it covers. `class_pair` joins
them.

Rosters and grading sheets list the option's students who are enrolled in a covered
class, and each row includes `group_id` and `class_pair`. The `group_id` filters on
lessons, homework, substitutions and teacher lateness match any covered class.
Lesson grade reports use the student's own class.

## Data Shape

```json
{
	"id": 5012,
	"academic_year_id": 1,
	"timetable_version_id": 3,
	"timetable_entry_id": 88,
	"date": "2026-10-05",
	"day": 1,
	"group_id": 12,
	"grade": 7,
	"class": "B",
	"class_pair": "7-B",
	"subgroup_id": null,
	"subgroup": null,
	"subject_id": 4,
	"subject": "Mathematics",
	"teacher_id": 15,
	"teacher": "Ali Valiyev",
	"additional_teacher_ids": [],
	"substitute_teacher_id": null,
	"substitute_teacher": null,
	"room_id": 4,
	"room": "A-12",
	"period_id": 17,
	"period_number": 2,
	"time_id": 2,
	"start_time": "09:20:00",
	"end_time": "10:05:00",
	"status": "scheduled",
	"cancel_reason": null,
	"attendance_marked": 27,
	"topic_logged": true,
	"homework_count": 1
}
```

- `status`: `scheduled`, `cancelled`, or `substituted` (see [Substitutions](substitutions.md)).
- `attendance_marked`: number of students with a mark.
- `grades_entered`: number of students with at least one teacher-entered grade category.

## Endpoints

### 1) List lessons
`GET /lesson-instances`

Query params:
- `date` (`YYYY-MM-DD`) or `from` + optional `to`. A range covers at most 62 days.
- optional `academic_year_id`, `group_id`, `subject_id`, `room_id`, `status`.
- optional `teacher_id`: matches the primary, an additional, or the substitute teacher.
- For one date across the whole school (including text entries and an
  `effective_teacher`), see `GET /timetable/day` in [Timetable](timetable.md).

Sorted by date, start time, class.

Response `200`: `{ "ok": true, "message": "Lesson instances retrieved successfully", "meta": { "total": 6 }, "result": [ ...lessons ] }`

### 2) Open a lesson
`GET /lesson-instances/:id`

The lesson plus:
- `students`: the roster on that date. That's enrollments in the class whose
  `join_date`/`leave_date` cover the date, limited to subgroup members for a
  subgroup lesson. Each student has their mark (`status`/`reason`, or `null`
  if unmarked).
- `topic`: the class register entry, or `null`.
- `homework`: homework set in this lesson.

```json
{
	"ok": true,
	"message": "Lesson retrieved successfully",
	"result": {
		"id": 5012,
		"subject": "Mathematics",
		"class_pair": "7-B",
		"date": "2026-10-05",
		"students": [
			{ "student_id": 101, "person_id": 55, "full_name": "Aziza Karimova", "status": "present", "reason": null },
			{ "student_id": 102, "person_id": 56, "full_name": "Bekzod Aliyev", "status": null, "reason": null }
		],
		"topic": { "id": 9, "topic": "Adding fractions", "notes": "Textbook p. 42", "user_plan_id": 31 },
		"homework": [ { "id": 3, "title": "Exercises 1–5", "due_date": "2026-10-07", "status": "assigned" } ]
	}
}
```

Possible errors: `404 Not Found`: `Lesson not found`

### 3) Take attendance
`PUT /lesson-instances/:id/attendance`

Saves marks for any number of students (unlisted students keep their mark or
stay unmarked). Send it again to change marks.

```json
{
	"marks": [
		{ "student_id": 101, "status": "present" },
		{ "student_id": 102, "status": "late", "minutes_late": 9, "reason": "Bus" },
		{ "student_id": 103, "status": "absent" }
	]
}
```

- `student_id` is the enrollment (`students.id`), not the person.
- `status`: `present`, `late`, `absent`, `excused`.
- `minutes_late` (1–600): required when `late`, not allowed otherwise.

**Daily attendance roll-up.** Each marked student's daily
[attendance](attendance.md) row for that date is rewritten from all their
lesson marks that day (cancelled lessons are ignored):
- missed every marked lesson → `excused` if every one was excused, else `absent`;
- otherwise, first marked lesson missed or late → `late`;
- otherwise → `present`.

This means existing daily reports and statistics include lesson attendance.
A daily status set by hand is overwritten once lesson marks exist that day.

**Daily score, category 1.** Saving a mark also sets the student's
`attendance_score` for the lesson:
- `present` → 20; the teacher marks categories 2–5.
- `late` → `20 × (45 − minutes_late) / 45`, rounded to one decimal (9 minutes →
  16; 45 or more → 0). Categories 2–5 are marked as normal.
- `absent` / `excused` → all five categories are 0 and the teacher can't
  change them (a [make-up](#6-make-up-score-absent-students) can raise the score later).
- Changing an absent student to `present`/`late` clears those zeros (and any
  make-up) so they can be graded.

Each change is kept in the [grade history](#7-grade-history).

Response `200`: the lesson detail (as in "Open a lesson"), with `message: "Attendance saved"`.

Possible errors:
- `400 Bad Request`: `Student 140 is not in this lesson's class on 2026-10-05`;
  `Student 101 is listed twice`; `minutes_late is required for late student 102`;
  `minutes_late is only for late students (student 101)`
- `403 Forbidden`: `You can only edit lessons you teach`
- `404 Not Found`
- `409 Conflict`: `This lesson is cancelled`

### 4) Grading sheet (daily score)
`GET /lesson-instances/:id/grades`

The full-screen grading pop-up for a lesson. Each student on the roster has a
daily score out of 100 made of five categories of 0–20
([Lesson Grades](lesson-grades.md)). Empty categories count as 0.

```json
{
	"ok": true,
	"message": "Lesson grades retrieved successfully",
	"meta": { "total": 27, "graded": 26, "average": 78.5 },
	"result": {
		"id": 5012,
		"subject": "Mathematics",
		"class_pair": "7-B",
		"date": "2026-10-05",
		"students": [
			{
				"student_id": 101, "person_id": 55, "full_name": "Aziza Karimova",
				"status": "late", "minutes_late": 9,
				"attendance_score": 16, "materials_score": 20, "homework_score": 15,
				"activity_score": 18, "notes_score": 17, "total": 86,
				"makeup_score": null, "makeup_at": null, "is_made_up": false, "score": 86,
				"comment": null, "client_saved_at": "2026-10-05T09:58:12.000Z"
			},
			{
				"student_id": 102, "person_id": 56, "full_name": "Bekzod Aliyev",
				"status": "absent", "minutes_late": null,
				"attendance_score": 0, "materials_score": 0, "homework_score": 0,
				"activity_score": 0, "notes_score": 0, "total": 0,
				"makeup_score": 72, "makeup_at": "2026-11-03T08:10:00.000Z", "is_made_up": true, "score": 72,
				"comment": "Showed homework on fractions", "client_saved_at": null
			}
		]
	}
}
```

- `status` / `minutes_late`: the student's attendance mark (`null` if unmarked).
- `total`: the five categories (empty ones count as 0). `score`: the daily score
  that counts, which is `makeup_score` when `is_made_up`, else `total`. Show a
  made-up score as `0 → 72 (make-up, 3 Nov)` from `total`, `makeup_score` and `makeup_at`.
- `meta.graded`: students with a grade row; `meta.average`: their average `score`.

### 5) Enter grades
`PUT /lesson-instances/:id/grades`

```json
{
	"grades": [
		{ "student_id": 101, "materials_score": 20, "homework_score": 15, "activity_score": 18, "notes_score": 17, "client_saved_at": "2026-10-05T09:58:12Z" },
		{ "student_id": 103, "materials_score": 5, "homework_score": 0, "activity_score": 10, "notes_score": 5, "comment": "No books, homework not done" }
	]
}
```

- Each category is an integer 0–20. Omitted fields keep their value; `null` clears it.
  The client offers the quick values (20, 15, 10, 5, 0) and "fill 20 for all"
  per column, then sends the whole sheet.
- `attendance_score` can't be sent: it comes from the attendance mark.
- Absent / excused students stay at 0: sending `0` or `null` is accepted
  (so "fill 0" columns work), anything else is `400`. A comment is allowed.
- **Low scores need a reason:** if a graded student's daily score is below 40,
  the save is rejected unless the student has a comment (sent now or already
  stored). The automatic 0 for absence is excluded. Parents see the comment.
- **Offline:** the app saves grades on the device first and sends them when
  online, with `client_saved_at` = when the teacher saved on the device. If the
  server already has a newer device save for that student, the entry is skipped
  and listed in `meta.stale` (the rest of the request is saved). Sending the
  same request twice is harmless.
- Unlisted students are untouched. No edit window: past lessons can be graded.
- Every change is kept in the [grade history](#7-grade-history).

Response `200`: the grading sheet, with `message: "Grades saved"` and
`meta.stale: []`.

Possible errors:
- `400 Bad Request`: `Student 140 is not in this lesson's class on 2026-10-05`;
  `Student 101 is listed twice`; `Mark attendance for student 102 first`;
  `Student 104 is absent: scores stay 0 (use a make-up instead)`;
  `Student 103's daily score is 20 (below 40): add a comment explaining why`
- `403`, `404`, `409`: as for attendance. The whole request is rolled back on an error.

### 6) Make-up score (absent students)
`PUT /lesson-instances/:id/grades/:studentId/make-up`

An absent student (excused or not) gets 0 for the lesson. If they later show
the teacher they understood the topic (through the homework), the teacher can
raise that lesson's score to at most 80.

```json
{ "score": 72, "comment": "Showed homework on fractions" }
```

- `score`: 0–80, one decimal at most. `comment` optional.
- Only for students marked `absent` or `excused` in this lesson.
- The categories stay 0 (`total: 0`); `score` becomes 72 and `is_made_up`,
  `makeup_at` mark it for teachers, admins and parents.
- Setting it again replaces it; `DELETE` on the same path removes it.
  The original 0 and every change stay in the history.
- Same ownership rule as attendance.

Response `200`: the grading sheet, with `message: "Make-up saved"` / `"Make-up removed"`.

Possible errors: `400 A make-up is only for students absent from this lesson`;
`400` if `score` is above 80; `403`, `404`, `409` as for attendance.

### 7) Grade history
`GET /lesson-instances/:id/grades/:studentId/history`

Every change to one student's grade in the lesson, oldest first. `action` is
`attendance` (from a mark), `grade` (teacher scores/comment) or `make_up`.
`before` is `null` for the first entry.

```json
{
	"ok": true,
	"message": "Grade history retrieved successfully",
	"meta": { "total": 2 },
	"result": [
		{
			"id": 1, "action": "attendance", "before": null,
			"after": { "attendance_score": 0, "materials_score": 0, "homework_score": 0, "activity_score": 0, "notes_score": 0, "total": 0, "makeup_score": null, "score": 0, "comment": null },
			"changed_at": "2026-10-05T09:21:00.000Z", "changed_by_id": 15, "changed_by": "Ali Valiyev"
		},
		{
			"id": 7, "action": "make_up",
			"before": { "total": 0, "makeup_score": null, "score": 0, "...": "..." },
			"after": { "total": 0, "makeup_score": 72, "score": 72, "comment": "Showed homework on fractions", "...": "..." },
			"changed_at": "2026-11-03T08:10:00.000Z", "changed_by_id": 15, "changed_by": "Ali Valiyev"
		}
	]
}
```

### 8) Log the topic (class register)
`PUT /lesson-instances/:id/topic`

```json
{
	"topic": "Adding fractions",
	"notes": "Textbook p. 42",
	"user_plan_id": 31
}
```

- One topic per lesson; sending again replaces it.
- `topic`: 1–255 characters; `notes`: optional, up to 5000.
- `user_plan_id`: optional link to one of your [plans](user-plans.md). With
  `manage` permission, any user's plan can be linked.

Response `200`: the lesson detail, with `message: "Topic saved"`.

Possible errors: as for attendance, plus `400 You can only link your own plans`,
`404 Plan with id 31 not found`.

### 9) Remove the topic
`DELETE /lesson-instances/:id/topic` → `204`

### 10) Generate / re-sync
`POST /lesson-instances/generate`

Permission: `lesson_instances.create`.

```json
{ "from": "2026-09-02", "to": "2026-10-31", "academic_year_id": 1 }
```

- Up to 400 days. `academic_year_id` is optional (all years).
- Idempotent.
- Past dates are handled with the same rules: instances with records are
  never deleted.

Response `200`:
```json
{ "ok": true, "message": "Lesson instances synced with the published timetable", "result": { "created": 812, "updated": 4, "removed": 2, "cancelled": 0 } }
```
