# Project Documentation

Two kinds of docs live here:

- **API references** — one file per backend feature (`attendance.md`, `points.md`, `contacts.md`, …). Endpoint shape, auth, examples.
- **Internal docs** — architecture & history:
  - `STRUCTURE.md` — proposed/target file structure & conventions
  - `CHANGELOG.md` — every notable change we make, newest first

## Convention (must follow)

1. **Every new feature** gets an API doc here (copy the shape of `attendance.md`).
2. **Every change** to the codebase gets a dated entry in `CHANGELOG.md`.
3. Architecture decisions update `STRUCTURE.md`.

## Index

| Doc | What |
|-----|------|
| [STRUCTURE.md](STRUCTURE.md) | Target file structure |
| [CHANGELOG.md](CHANGELOG.md) | Change history |
| [PUSH_SETUP.md](PUSH_SETUP.md) | Firebase/APNs steps needed before push works |
| [attendance.md](attendance.md) | Attendance API |
| [points.md](points.md) | Student points API |
| [contacts.md](contacts.md) | Contacts API |
| [staff/notifications.md](staff/notifications.md) | Notifications API — inbox, device tokens, send |
| [staff/branches.md](staff/branches.md) | Branches API — `X-Branch-Id`, what each selection reads and writes |
| [staff/lesson-instances.md](staff/lesson-instances.md) | Lesson records — attendance, cancelling |
| [staff/lesson-grades.md](staff/lesson-grades.md) | Daily scores — categories, comment rule, edit window |
| [staff/bell-schedules.md](staff/bell-schedules.md) | The periods of the school day |
