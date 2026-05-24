# Table: PublicHolidayReview

**OutSystems Entity**: PublicHolidayReview
**Module**: RosterManagement_CS
**Database Table**: {PublicHolidayReview}
**Purpose**: Stores per-employee public holiday review records, tracking whether a PH is observed/entitled on a specific date.
**Last Updated**: 2026-05-24

---

## Overview

When a Public Holiday falls on a weekend (Sat/Sun), it can be "Mondayized" — meaning the following Monday becomes the observed PH. Each employee may observe the PH on either the original date or the Mondayized date, depending on their work schedule and other factors.

PublicHolidayReview stores the **per-employee decision** of which day they observe. This is critical for the Leave Release Detail screen where PH badges should only show on the day the employee actually observes the holiday.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | BIGINT | PK, NOT NULL | Primary key, auto-increment |
| `EmployeeWeekId` | BIGINT | FK, NOT NULL | Links to EmployeeWeek — identifies the employee + week |
| `HolidayDate` | DATE | NOT NULL | The actual date of the public holiday for this review record |
| `IsEntitledBySystem` | BIT | NOT NULL | Whether the system has determined this employee is entitled to the PH |
| `IsEntitledByOverride` | BIT | NOT NULL | Whether a manager has manually overridden the entitlement |
| `IsObserved` | BIT | NOT NULL | **Key column**: Whether this employee observes the PH on this date. `1` = observed, `0` = not observed |
| `RosterWeekPHReviewId` | BIGINT | FK, NOT NULL | Links to RosterWeekPublicHolidayReview — the week-level PH review |

---

## Key Constraints

### Primary Key
- `Id` - Unique identifier for each review record

### Foreign Keys
- `EmployeeWeekId` → `EmployeeWeek`.`Id`
  - Relationship: Many-to-One (many PH reviews per employee week)
- `RosterWeekPHReviewId` → `RosterWeekPublicHolidayReview`.`Id`
  - Relationship: Many-to-One

---

## Relationships

### Tables This Table References
- **[EmployeeWeek](../EmployeeWeek/README.md)** - Identifies which employee and which week
  - Join: `PublicHolidayReview.EmployeeWeekId = EmployeeWeek.Id`
  - Through EmployeeWeek → BusinessUser to get the employee
- **[RosterWeekPublicHolidayReview](../RosterWeekPublicHolidayReview/README.md)** - Week-level PH review container
  - Join: `PublicHolidayReview.RosterWeekPHReviewId = RosterWeekPublicHolidayReview.Id`

---

## Entity Actions

- **CreatePublicHolidayReview** - Create a new record
- **CreateOrUpdatePublicHolidayReview** - Upsert
- **UpdatePublicHolidayReview** - Update existing record
- **GetPublicHolidayReview** - Get by Id
- **GetPublicHolidayReviewForUpdate** - Get for update (locking)

---

## Business Logic: Mondayized Public Holidays

When a PH is Mondayized, **two PublicHolidayReview records** exist for the employee (with different `HolidayDate` values):
1. One for the original PH date (e.g., Saturday 28 Feb) — `IsObserved = 0` or `1`
2. One for the Mondayized date (e.g., Monday 2 Mar) — `IsObserved = 1` or `0`

**Only one** of these will have `IsObserved = 1` for a given employee. The PH badge on the Leave Release Detail screen should only show on the day where `IsObserved = 1`.

### Entitlement Logic
- `IsEntitledBySystem` — System-calculated entitlement based on employee schedule/rules
- `IsEntitledByOverride` — Manager can manually override the system decision
- An employee is entitled if **either** flag is true (confirm this logic)

### Example: 28 Feb 2025 PH (Mondayized to 2 Mar 2025)
- Employee A works weekdays → observes on Mon 2 Mar → `IsObserved = 1` for `HolidayDate = 2025-03-02`
- Employee B works weekends → observes on Sat 28 Feb → `IsObserved = 1` for `HolidayDate = 2025-02-28`

---

## Common Query Patterns

### Get observed PH for an employee in a week
```sql
SELECT phr.Id, phr.HolidayDate, phr.IsObserved, phr.IsEntitledBySystem, phr.IsEntitledByOverride
FROM {PublicHolidayReview} phr
INNER JOIN {EmployeeWeek} ew ON ew.Id = phr.EmployeeWeekId
WHERE ew.BusinessUserId = @BusinessUserId
  AND phr.IsObserved = 1
```

---

## Related Tables

- [EmployeeWeek](../EmployeeWeek/README.md) - Employee-week assignment
- [RosterWeekPublicHolidayReview](../RosterWeekPublicHolidayReview/README.md) - Week-level PH review

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-05-24 | Claude + Abdul | Initial documentation for story 3825 |
| 2026-05-24 | Claude + Abdul | Fixed columns from entity screenshot — removed incorrect PublicHolidayId and audit fields, added HolidayDate, IsEntitledBySystem, IsEntitledByOverride |
