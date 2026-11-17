# Lesson Grades API (daily score)

**Base path:** `/lesson-grades`

Every lesson, each student gets a **daily score out of 100**: five categories
of 0–20 points. Grades are entered on the lesson
([Lesson Instances](lesson-instances.md) → `PUT /lesson-instances/:id/grades`);
this module only reports on them.

| # | Category | Column | Filled by |
| --- | --- | --- | --- |
| 1 | Attendance and punctuality | `attendance_score` | Automatically from lesson attendance |
| 2 | Has books and notebooks | `materials_score` | Teacher |
| 3 | Homework done, correct and accurate | `homework_score` | Teacher |
| 4 | Activeness in the lesson | `activity_score` | Teacher |
| 5 | Note-taking: notebook clean, accurate, organized | `notes_score` | Teacher |
| | Daily score | `total` | Sum of the five |

Only grades (their class's branch) at the branches selected by `X-Branch-Id` are visible; see
[Branches](branches.md#scoped-data).

## Rules
- **Attendance category** (from the [lesson attendance](lesson-instances.md#3-take-attendance) mark):
  `present` → 20; `late` → `20 × (45 − minutes_late) / 45`, one decimal
  (9 minutes → 16, 45+ → 0); `absent` / `excused` → 0. Teachers can't set it.
- **Absent / excused** students get 0 in all five categories, fixed. A
  **make-up** can later raise the lesson's score to at most 80; the original 0
  stays in `total` and in the history, and `is_made_up` / `makeup_at` mark it.
- **`score`** is the daily score that counts: `makeup_score` if any, else `total`.
- **Low scores need a reason:** a teacher-graded score below 40 can't be saved
  without a comment (absence 0 excluded).
- **Empty categories count as 0** in `total`, `score` and every average.
- Every change is kept in `lesson_grade_history`.
- Cancelled lessons are left out of all lists and statistics.
- No edit window: teachers can correct grades for any past lesson they teach.

## Auth
- Permission: `lesson_grades.read` (admin and teacher by default).
- Without `lesson_grades.read_all`, a viewer sees grades of lessons they teach
  and of their homeroom classes; an HOD also sees the subjects of the
  [departments they lead](departments.md#hod-scope), in those departments'
  branches.

## Endpoints

| Method | Path | Description |
| --- | --- | --- |
| GET | `/lesson-grades` | List grade rows (paginated) |
| GET | `/lesson-grades/statistics` | Averages over the filters |
| GET | `/lesson-grades/statistics/by-student` | Averages per student |
| GET | `/lesson-grades/statistics/by-group` | Averages per group |
| GET | `/lesson-grades/statistics/by-subject` | Averages per subject |
| GET | `/lesson-grades/statistics/matrix` | [Performance matrix](#performance-matrix): rows × terms or months |

All endpoints except the matrix share the optional filters: `student_id` (enrollment),
`person_id`, `group_id`, `subject_id`, `teacher_id` (primary or additional
teacher), `start_date` / `end_date` (inclusive, lesson date).

### List
- **GET** `/lesson-grades?group_id=4&start_date=2026-10-01&end_date=2026-10-31&page=1&limit=50`
- `page` (default 1), `limit` (default 50, max 200).
- Sorted by lesson date and time (newest first), then student name.

```json
{
  "ok": true,
  "message": "Lesson grades retrieved successfully",
  "meta": { "total": 1, "page": 1, "limit": 50 },
  "result": [
    {
      "id": 3001,
      "lesson_instance_id": 5012,
      "date": "2026-10-05",
      "start_time": "09:20:00",
      "student_id": 101,
      "person_id": 55,
      "full_name": "Aziza Karimova",
      "group_id": 4,
      "class_pair": "7-B",
      "subject_id": 4,
      "subject": "Mathematics",
      "teacher_id": 15,
      "attendance_status": "late",
      "minutes_late": 9,
      "attendance_score": 16,
      "materials_score": 20,
      "homework_score": 15,
      "activity_score": 18,
      "notes_score": null,
      "total": 69,
      "makeup_score": null,
      "makeup_at": null,
      "is_made_up": false,
      "score": 69,
      "comment": null,
      "updated_at": "2026-10-05T09:55:00.000Z"
    }
  ]
}
```

### Statistics
Every bucket has:
`lessons`, `average_score` (the scores that count, make-ups included),
`average_total` (categories only), `average_attendance`, `average_materials`,
`average_homework`, `average_activity`, `average_notes` (2 decimals, `null`
when there are no rows) and `made_up` (number of made-up lessons). `meta` echoes the filters (unused ones as `null`);
grouped endpoints add `meta.total` = number of buckets.

- `/statistics` → one bucket.
- `/statistics/by-student` → plus `student_id`, `person_id`, `full_name`; ordered by name.
- `/statistics/by-group` → plus `group_id`, `group_name`, `grade`, `class`, `class_pair`; ordered by grade, class.
- `/statistics/by-subject` → plus `subject_id`, `subject`; ordered by name.

```http
GET /lesson-grades/statistics/by-student?group_id=4&start_date=2026-10-01
```
```json
{
  "ok": true,
  "message": "Lesson grade statistics by student retrieved successfully",
  "meta": { "group_id": 4, "start_date": "2026-10-01", "total": 1 },
  "result": [
    {
      "student_id": 101,
      "person_id": 55,
      "full_name": "Aziza Karimova",
      "lessons": 18,
      "average_score": 82.1,
      "average_total": 81.5,
      "average_attendance": 19.44,
      "average_materials": 17.22,
      "average_homework": 15.83,
      "average_activity": 15.56,
      "average_notes": 13.44,
      "made_up": 1
    }
  ]
}
```

Possible errors: `400 end_date must be on or after start_date`.

## Performance matrix
- **GET** `/lesson-grades/statistics/matrix` (`lesson_grades.read`)
- One pivot of **rows × columns × one value**: students or subjects as rows,
  [academic terms](academic-terms.md) (possibly from several years) or the
  months of one term as columns.

| Param | Required | Meaning |
| --- | --- | --- |
| `row` | yes | `student` or `subject` |
| `column` | yes | `term` or `month` |
| `source` | yes | `score`, `attendance`, `materials`, `homework`, `activity`, `notes` or `exam` |
| `term_ids` | with `column=term` | Comma-separated, max 12 |
| `term_id` | with `column=month` | One term; its months become the columns |
| `group_ids` | with `row=student` | Comma-separated, max 20; whose students to list |
| `person_id` | with `row=subject` | The one student |
| `subject_id` | no | Limits to one subject (omitted: all subjects together) |

Any other combination, or an unknown id, is a `400`.

| `source` | Cell value | `meta.scale_max` |
| --- | --- | --- |
| `score` | Average daily score (make-ups included) | 100 |
| category | Average of that category, empty counting as 0 | 20 |
| `exam` | Average of `score / max_score × 100` of exams whose period date is in the column | 100 |

### Rules
- **Students are followed by person**, so a row has their scores from every
  class and year in the columns (a student who moved from 9A to 10A keeps one
  row). The row's `group_id` / `class` is their class among `group_ids`.
- **Who is listed (`row=student`):** students of `group_ids` who haven't left
  (`leave_date` empty or in the future), plus anyone else enrolled there with a
  value. A viewer without `lesson_grades.read_all` only gets rows with values
  they can see.
- **Month columns** are calendar months cut to the term's dates, keyed
  `YYYY-MM`.
- **No data is `null`** (`count: 0`), never 0.
- **Averages use only non-null values, before rounding** (2 decimals out):
  `average` is the mean of the row's cells; `column_averages[key]` is the mean
  of the row values in that column (each student counts once, unlike
  `average_score` on `/by-group`); `overall_average` is the mean of the row
  averages.
- **`row=subject`** rows are the subjects the student has values in. Each also
  has `class_averages[key]`: the mean of the values of the class the student
  was in that column's year (classmates who left included if they have values),
  or `null` if they weren't enrolled that year.
- Cancelled lessons are left out and choice-lesson students stay in their own
  class, as everywhere else. The viewer scope is the same as the other
  endpoints. For exams (which have no teacher) a viewer without `read_all`
  sees a result when, in the exam's year, they are the student's homeroom
  teacher, gave the student a graded lesson in that subject, or lead the
  [department](departments.md#hod-scope) of that subject at the exam period's
  branch.
- Rows are ordered by name, columns by date. `count` is the number of lessons
  (exams for `source=exam`). Differences, shading and score ranges are left to
  the frontend.

```http
GET /lesson-grades/statistics/matrix?row=student&column=term&source=score&term_ids=1,2&group_ids=7&subject_id=4
```
```json
{
  "ok": true,
  "message": "Performance matrix retrieved successfully",
  "meta": { "row": "student", "column": "term", "source": "score", "scale_max": 100, "total": 2 },
  "result": {
    "columns": [
      { "key": "1", "label": "2025-2026 · 1st halfyear", "start_date": "2025-09-01", "end_date": "2026-01-24" },
      { "key": "2", "label": "2026-2027 · 1st halfyear", "start_date": "2026-09-01", "end_date": "2027-01-24" }
    ],
    "rows": [
      {
        "person_id": 55,
        "name": "Aziza Karimova",
        "group_id": 7,
        "class": "10-A",
        "values": { "1": { "value": 80, "count": 18 }, "2": { "value": 90, "count": 20 } },
        "average": 85
      },
      {
        "person_id": 56,
        "name": "Bobur Aliyev",
        "group_id": 7,
        "class": "10-A",
        "values": { "1": { "value": null, "count": 0 }, "2": { "value": 70, "count": 19 } },
        "average": 70
      }
    ],
    "column_averages": { "1": 80, "2": 80 },
    "overall_average": 77.5
  }
}
```

A `row=subject` row instead looks like:

```json
{
  "subject_id": 4,
  "name": "Mathematics",
  "values": { "1": { "value": 79, "count": 22 } },
  "class_averages": { "1": 76.32 },
  "average": 79
}
```

Month columns look like
`{ "key": "2026-01", "label": "January 2026", "start_date": "2026-01-26", "end_date": "2026-01-31" }`.

