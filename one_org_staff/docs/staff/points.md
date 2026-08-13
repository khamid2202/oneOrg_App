# Points API

**Base path:** `/student-points`

Manage student point records (scores/points system). Points are keyed by
`person_id` (the person, not the enrollment).

## Auth
- Guard: `RolesGuard`; no per-endpoint permissions — any authenticated staff
  user. `UserId` from the token is used for audit fields.

## Endpoints

| Method | Path | Description |
| --- | --- | --- |
| GET | `/student-points` | List points (filtered, paginated) |
| GET | `/student-points/statistics` | Summary aggregates |
| GET | `/student-points/statistics/trend` | Aggregates per date |
| GET | `/student-points/statistics/by-student` | Aggregates per student |
| GET | `/student-points/statistics/by-group` | Aggregates per group |
| GET | `/student-points/statistics/by-subject` | Aggregates per subject |
| GET | `/student-points/statistics/by-teacher` | Aggregates per teacher |
| GET | `/student-points/statistics/by-reason` | Aggregates per reason |
| POST | `/student-points` | Create (or upsert) a point |
| POST | `/student-points/bulk` | Create points in bulk |
| PATCH | `/student-points/:id` | Update a point |
| DELETE | `/student-points/:id` | Delete a point |

### List points
- **GET** `/student-points`
- **Query (GetPointsDto), all optional:** `person_id`, `group_id`,
  `subject_id`, `reason` (partial match), `start_date` / `end_date`,
  `page` (default `1`), `limit` (default `20`).
- Sorted by `date DESC`, then `created_at DESC`. Includes joined display fields
  (`student_name`, `subject_name`, `teacher_name`, class pair fields);
  `created_by` / `updated_by` are resolved to user full names.
- `meta` contains `total`, `total_points` (sum over the returned page), and the
  echoed query.

**Example request**
```http
GET /student-points?group_id=5&start_date=2025-10-01&end_date=2025-10-31&page=1&limit=20
```

**Example response**
```json
{
  "ok": true,
  "message": "Points retrieved successfully",
  "meta": {
    "total": 1,
    "total_points": 8,
    "group_id": 5,
    "start_date": "2025-10-01",
    "end_date": "2025-10-31",
    "page": 1,
    "limit": 20
  },
  "points": [
    {
      "id": 701,
      "person_id": 100,
      "group_id": 5,
      "subject_id": 3,
      "subject_name": "Mathematics",
      "points": 8,
      "reason": "Quiz",
      "date": "2025-10-02",
      "student_name": "Ali Valiyev",
      "group_grade": 10,
      "group_class": "A",
      "class_pair": "10-A",
      "class_pair_compact": "10A",
      "teacher_name": "John Doe",
      "created_by": "John Doe",
      "created_at": "2025-10-02T10:00:00.000Z",
      "updated_by": null,
      "updated_at": null
    }
  ]
}
```

## Statistics

All `/student-points/statistics*` endpoints share the same filter set
(`GetPointStatisticsDto`, all optional) and aggregate over point rows. Every
response echoes the applied filters under `meta`; grouped endpoints also add
`meta.total` = number of buckets (`meta` examples below are abbreviated to the
non-null filters).

| Filter | Applies to |
| --- | --- |
| `person_id` | student |
| `group_id` | group |
| `subject_id` | subject |
| `teacher_id` | awarding teacher |
| `reason` | reason (partial match) |
| `date` | exact point `date` |
| `start_date` / `end_date` | point `date` range (inclusive) |

Point sums use `SUM(points)`, so awarded (positive) and deducted (negative)
points net out in `total_points`.

### Summary
- **GET** `/student-points/statistics`
- `result`: `{ total_records, total_points, positive_points, negative_points, average_points, distinct_students, distinct_groups, distinct_subjects }`.

**Example request**
```http
GET /student-points/statistics?group_id=5
```

**Example response**
```json
{
  "ok": true,
  "message": "Point statistics retrieved successfully",
  "meta": {
    "person_id": null, "group_id": 5, "subject_id": null, "teacher_id": null,
    "reason": null, "date": null, "start_date": null, "end_date": null
  },
  "result": {
    "total_records": 340,
    "total_points": 1275,
    "positive_points": 1400,
    "negative_points": -125,
    "average_points": 3.75,
    "distinct_students": 28,
    "distinct_groups": 1,
    "distinct_subjects": 6
  }
}
```

### Trend
- **GET** `/student-points/statistics/trend`
- `result`: `[{ date, total_records, total_points }]` ordered by `date` ascending.

**Example request**
```http
GET /student-points/statistics/trend?group_id=5&start_date=2025-10-01&end_date=2025-10-31
```

**Example response**
```json
{
  "ok": true,
  "message": "Point trend retrieved successfully",
  "meta": { "group_id": 5, "start_date": "2025-10-01", "end_date": "2025-10-31", "total": 2 },
  "result": [
    { "date": "2025-10-02", "total_records": 24, "total_points": 96 },
    { "date": "2025-10-09", "total_records": 22, "total_points": 84 }
  ]
}
```

### By student
- **GET** `/student-points/statistics/by-student`
- `result`: `[{ person_id, student_name, total_records, total_points }]`, highest `total_points` first.

**Example request**
```http
GET /student-points/statistics/by-student?group_id=5
```

**Example response**
```json
{
  "ok": true,
  "message": "Point statistics by student retrieved successfully",
  "meta": { "group_id": 5, "total": 2 },
  "result": [
    { "person_id": 100, "student_name": "Ali Valiyev", "total_records": 14, "total_points": 62 },
    { "person_id": 101, "student_name": "Laylo Karimova", "total_records": 12, "total_points": 55 }
  ]
}
```

### By group
- **GET** `/student-points/statistics/by-group`
- `result`: `[{ group_id, grade, class, total_records, total_points }]`.

**Example request**
```http
GET /student-points/statistics/by-group?subject_id=3
```

**Example response**
```json
{
  "ok": true,
  "message": "Point statistics by group retrieved successfully",
  "meta": { "subject_id": 3, "total": 2 },
  "result": [
    { "group_id": 5, "grade": 10, "class": "A", "total_records": 120, "total_points": 460 },
    { "group_id": 6, "grade": 10, "class": "B", "total_records": 110, "total_points": 405 }
  ]
}
```

### By subject
- **GET** `/student-points/statistics/by-subject`
- `result`: `[{ subject_id, subject_name, total_records, total_points }]` (`subject_id: null` = points recorded without a subject).

**Example request**
```http
GET /student-points/statistics/by-subject?group_id=5
```

**Example response**
```json
{
  "ok": true,
  "message": "Point statistics by subject retrieved successfully",
  "meta": { "group_id": 5, "total": 2 },
  "result": [
    { "subject_id": 3, "subject_name": "Mathematics", "total_records": 80, "total_points": 320 },
    { "subject_id": null, "subject_name": null, "total_records": 12, "total_points": 30 }
  ]
}
```

### By teacher
- **GET** `/student-points/statistics/by-teacher`
- `result`: `[{ teacher_id, teacher_name, total_records, total_points }]`.

**Example request**
```http
GET /student-points/statistics/by-teacher
```

**Example response**
```json
{
  "ok": true,
  "message": "Point statistics by teacher retrieved successfully",
  "meta": { "total": 1 },
  "result": [
    { "teacher_id": 12, "teacher_name": "John Doe", "total_records": 210, "total_points": 800 }
  ]
}
```

### By reason
- **GET** `/student-points/statistics/by-reason`
- `result`: `[{ reason, total_records, total_points }]`, most frequent first.

**Example request**
```http
GET /student-points/statistics/by-reason?group_id=5
```

**Example response**
```json
{
  "ok": true,
  "message": "Point statistics by reason retrieved successfully",
  "meta": { "group_id": 5, "total": 2 },
  "result": [
    { "reason": "Quiz", "total_records": 90, "total_points": 350 },
    { "reason": "Homework", "total_records": 70, "total_points": 260 }
  ]
}
```

### Create point
- **POST** `/student-points`
- **Body (CreatePointDto):**
  - `person_id` (int, required)
  - `group_id` (int, required)
  - `subject_id` (int, optional)
  - `points` (number, required)
  - `date` (ISO date string, required)
  - `reason` (string, optional)
- **Behavior:**
  - validates person, group, membership, and that `date` falls inside the
    group's academic year
  - resolves `teacher_id` from the timetable when `subject_id` is provided
    (fallback: group teacher)
  - if a duplicate exists by `person_id`, `group_id`, `subject_id`,
    `teacher_id`, normalized `reason`, and `date`, the existing row is updated
    (message becomes `Point updated successfully`)

**Example request**
```json
{
  "person_id": 100,
  "group_id": 5,
  "subject_id": 3,
  "points": 8,
  "reason": "Quiz",
  "date": "2025-10-02"
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Point created successfully",
  "point": {
    "id": 701,
    "person_id": 100,
    "group_id": 5,
    "subject_id": 3,
    "teacher_id": 12,
    "points": 8,
    "reason": "Quiz",
    "date": "2025-10-02",
    "created_by": 12,
    "created_at": "2025-10-02T10:00:00.000Z"
  }
}
```

### Create points in bulk
- **POST** `/student-points/bulk`
- **Body:** JSON array of `CreatePointDto`. `400` if empty. Duplicates inside
  the payload are collapsed (last one wins); existing rows matching the
  duplicate key are updated.

**Example request**
```json
[
  { "person_id": 100, "group_id": 5, "subject_id": 3, "points": 8, "reason": "Quiz", "date": "2025-10-02" },
  { "person_id": 101, "group_id": 5, "subject_id": 3, "points": 7, "reason": "Quiz", "date": "2025-10-02" }
]
```

**Example response**
```json
{
  "ok": true,
  "message": "Points processed successfully",
  "total": 2,
  "received": 2,
  "collapsed_duplicates": 0,
  "created": 2,
  "updated": 0,
  "points": [
    { "id": 701, "person_id": 100, "group_id": 5, "subject_id": 3, "points": 8, "reason": "Quiz", "date": "2025-10-02" },
    { "id": 702, "person_id": 101, "group_id": 5, "subject_id": 3, "points": 7, "reason": "Quiz", "date": "2025-10-02" }
  ]
}
```

### Update point
- **PATCH** `/student-points/:id`
- **Body (UpdatePointDto):** partial of the create fields. Validates relations
  and date with the same rules as create; recalculates `teacher_id` when
  relevant fields change.

**Example request**
```http
PATCH /student-points/701
```
```json
{
  "points": 10
}
```

**Example response**
```json
{
  "ok": true,
  "message": "Point updated successfully",
  "point": {
    "id": 701,
    "person_id": 100,
    "group_id": 5,
    "subject_id": 3,
    "teacher_id": 12,
    "points": 10,
    "reason": "Quiz",
    "date": "2025-10-02",
    "updated_by": 12,
    "updated_at": "2025-10-03T09:00:00.000Z"
  }
}
```

### Delete point
- **DELETE** `/student-points/:id`
- `404`/`400` if not found.

**Example request**
```http
DELETE /student-points/701
```

**Example response**
```json
{
  "ok": true,
  "message": "Point deleted successfully"
}
```

## Frontend suggestions
- Use date pickers for `date`/range filters.
- Keep list pagination in state to avoid refetch churn.
