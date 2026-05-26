# Table: EmployeeWeek

**OutSystems Entity**: EmployeeWeek
**Module**: RosterManagement_CS
**Database Table**: {EmployeeWeek}
**Purpose**: Links an employee (BusinessUser) to a specific week, storing their weekly schedule status and flags.
**Last Updated**: 2026-05-24

---

## Overview

EmployeeWeek represents one employee's record for a specific week. It links to BusinessUser directly and uses `WeekEndDate` to identify the week (not a FK to RosterWeek). It serves as the parent for per-employee records like PublicHolidayReview.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | BIGINT | PK, NOT NULL | Primary key, auto-increment |
| `BusinessUserId` | BIGINT | FK, NOT NULL | The employee — links to BusinessUser |
| `WeekEndDate` | DATE | NOT NULL | The end date of the week this record covers |
| `IsSchoolOrUniHoliday` | BIT | | Whether this week falls during a school/university holiday for this employee |
| `AMH` | DECIMAL | | Agreed Minimum Hours — the employee's contracted minimum hours for this week |
| `EmployeeWeekStatusId` | BIGINT | FK | Status of this employee's week — links to EmployeeWeekStatus static entity |
| `HasLeaveApplied` | BIT | | Whether the employee has leave applied during this week |

---

## Key Constraints

### Primary Key
- `Id` - Unique identifier

### Foreign Keys
- `BusinessUserId` → `BusinessUser`.`Id`
  - Relationship: Many-to-One (an employee has many weeks)
- `EmployeeWeekStatusId` → EmployeeWeekStatus (static entity)

---

## Relationships

### Tables That Reference This Table
- **[PublicHolidayReview](../PublicHolidayReview/README.md)** - PH observation records per employee per week
  - Join: `PublicHolidayReview.EmployeeWeekId = EmployeeWeek.Id`

### Tables This Table References
- **[BusinessUser](../BusinessUser/README.md)** - The employee
  - Join: `EmployeeWeek.BusinessUserId = BusinessUser.Id`

---

## Important Notes

- **No direct FK to RosterWeek** — the week is identified by `WeekEndDate`, not by a `RosterWeekId` FK. To join to RosterWeek, match on date range: `ew.WeekEndDate BETWEEN rw.StartDate AND rw.EndDate` (or similar date logic).
- **AMH** = Agreed Minimum Hours — this is the employee's contractual minimum, relevant for leave/pay calculations.

---

## Common Query Patterns

### Get EmployeeWeek for a specific employee and week
```sql
SELECT ew.Id, ew.BusinessUserId, ew.WeekEndDate, ew.AMH, ew.HasLeaveApplied
FROM {EmployeeWeek} ew
WHERE ew.BusinessUserId = @BusinessUserId
  AND ew.WeekEndDate = @WeekEndDate
```

---

## Related Tables

- [BusinessUser](../BusinessUser/README.md) - Employee identity
- [PublicHolidayReview](../PublicHolidayReview/README.md) - Per-employee PH observations

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-05-24 | Claude + Abdul | Initial documentation for story 3825 |
| 2026-05-24 | Claude + Abdul | Fixed columns from entity screenshot — removed incorrect RosterWeekId, added WeekEndDate, AMH, IsSchoolOrUniHoliday, EmployeeWeekStatusId, HasLeaveApplied |
