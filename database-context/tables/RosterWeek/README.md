# Table: RosterWeek

**OutSystems Entity**: RosterWeek
**Module**: RosterManagement_CS
**Database Table**: {RosterWeek}
**Purpose**: Defines a roster week with start/end dates, site assignment, schedule status, and publish tracking.
**Last Updated**: 2026-05-24

---

## Overview

RosterWeek represents a single scheduling week for a site. It contains the week's date range, its current status (via ScheduleStatusId), and separate roster statuses for managers and crew. The status determines UI behavior — e.g., if a week is "Closed" (PayweekClosed), the Leave Release filter should default to "All" instead of "Pending".

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | BIGINT | PK, NOT NULL | Primary key, auto-increment |
| `SiteId` | BIGINT | FK, NOT NULL | The site this roster week belongs to |
| `StartDate` | DATE | NOT NULL | First day of the roster week |
| `EndDate` | DATE | NOT NULL | Last day of the roster week |
| `ScheduleStatusId` | BIGINT | FK, NOT NULL | Overall schedule status — links to ScheduleStatus static entity |
| `ManagersRosterStatusId` | BIGINT | FK | Roster status for managers — separate from crew status |
| `CrewRosterStatusId` | BIGINT | FK | Roster status for crew members — separate from manager status |
| `IsSandBox` | BIT | | Whether this is a sandbox/draft roster week (not live) |
| `UsingPartialPublishFlow` | BIT | | Whether partial publish flow is being used for this week |
| `PublishedBy` | BIGINT | FK | User who published the roster |
| `PublishedOn` | DATETIME | | Timestamp when the roster was published |

---

## Key Constraints

### Primary Key
- `Id` - Unique identifier

### Foreign Keys
- `SiteId` → `Site`.`Id`
- `ScheduleStatusId` → `ScheduleStatus` static entity (see values below)
- `ManagersRosterStatusId` → Roster status static entity (TBD — may be same as ScheduleStatus or separate)
- `CrewRosterStatusId` → Roster status static entity (TBD)
- `PublishedBy` → `User`.`Id` or `BusinessUser`.`Id`

---

## ScheduleStatus Values

| Id | Label | Description |
|----|-------|-------------|
| -1 | NotOpenedYet | Roster week has not been opened yet |
| 1 | RosterOpened | Roster is open and being edited |
| 2 | RosterPublished | Roster has been published to employees |
| 3 | TimecardsReleased | Timecards have been released |
| 4 | LeaveReleased | Leave has been released |
| 5 | PayweekClosed | Pay week is finalized and closed |

See [ScheduleStatus](../ScheduleStatus/README.md) for full details.

---

## Relationships

### Tables That Reference This Table
- **[EmployeeWeek](../EmployeeWeek/README.md)** - Employee assignments for this week (joined via date, not FK)
- **[RosterWeekPublicHolidayReview](../RosterWeekPublicHolidayReview/README.md)** - PH review records for this week
  - Join: `RosterWeekPublicHolidayReview.RosterWeekId = RosterWeek.Id`

### Tables This Table References
- **[Site](../Site/README.md)** - Which site this week is for
- **ScheduleStatus** (static entity) - Overall week status

---

## Important Notes

- **EmployeeWeek does NOT have a RosterWeekId FK** — EmployeeWeek uses `WeekEndDate` to identify the week. To join: match EmployeeWeek.WeekEndDate with RosterWeek date range.
- **Separate manager/crew statuses** — `ManagersRosterStatusId` and `CrewRosterStatusId` track independent status progression for managers vs crew.
- **IsSandBox** — Sandbox rosters are drafts that haven't gone live. Filter these out when querying for real roster data.

---

## Common Query Patterns

### Get roster week status for a site and date
```sql
SELECT rw.Id, rw.StartDate, rw.EndDate, rw.ScheduleStatusId
FROM {RosterWeek} rw
WHERE rw.SiteId = @SiteId
  AND rw.StartDate <= @Date
  AND rw.EndDate >= @Date
  AND rw.IsSandBox = 0
```

### Check if a week is closed
```sql
SELECT rw.Id
FROM {RosterWeek} rw
WHERE rw.SiteId = @SiteId
  AND rw.StartDate <= @Date
  AND rw.EndDate >= @Date
  AND rw.ScheduleStatusId = 5  -- PayweekClosed
```

---

## Related Tables

- [Site](../Site/README.md) - Site definition
- [EmployeeWeek](../EmployeeWeek/README.md) - Employee-week assignments (join via date)
- [RosterWeekPublicHolidayReview](../RosterWeekPublicHolidayReview/README.md) - Week-level PH reviews
- [ScheduleStatus](../ScheduleStatus/README.md) - Status values

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-05-24 | Claude + Abdul | Initial documentation for story 3825 |
| 2026-05-24 | Claude + Abdul | Fixed columns from entity screenshot — added ManagersRosterStatusId, CrewRosterStatusId, IsSandBox, UsingPartialPublishFlow, PublishedBy, PublishedOn |
