# Table: RosterWeekPublicHolidayReview

**OutSystems Entity**: RosterWeekPublicHolidayReview
**Module**: RosterManagement_CS
**Database Table**: {RosterWeekPublicHolidayReview}
**Purpose**: Links a RosterWeek to a PublicHoliday for review, tracking completion status, thresholds, and Mondayisation linkage.
**Last Updated**: 2026-05-24

---

## Overview

RosterWeekPublicHolidayReview is the week-level container for public holiday reviews. It connects a roster week to a specific public holiday and tracks whether the review process is complete. It also stores wage/salary thresholds used in PH entitlement calculations and supports Mondayisation via a self-referencing FK.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | BIGINT | PK, NOT NULL | Primary key, auto-increment |
| `RosterWeekId` | BIGINT | FK, NOT NULL | The roster week containing this PH — links to RosterWeek |
| `PublicHolidayId` | BIGINT | FK, NOT NULL | The public holiday being reviewed — links to PublicHoliday |
| `PublicHolidayDate` | DATE | NOT NULL | The date of the public holiday (denormalized from PublicHoliday for convenience) |
| `IsComplete` | BIT | NOT NULL | Whether the PH review for this week has been completed |
| `CompletedBy` | BIGINT | FK | User who completed the review |
| `CompletedAt` | DATETIME | | Timestamp when the review was completed |
| `WageThreshold` | DECIMAL | | Wage threshold used for PH entitlement calculation (hourly/waged employees) |
| `SalaryThreshold` | DECIMAL | | Salary threshold used for PH entitlement calculation (salaried employees) |
| `MondayisedFromReviewId` | BIGINT | FK (self) | Self-referencing FK — if this is a Mondayized PH review, points to the original weekend PH review record. `NULL` or `0` for original/non-Mondayized reviews |

---

## Key Constraints

### Primary Key
- `Id` - Unique identifier

### Foreign Keys
- `RosterWeekId` → `RosterWeek`.`Id`
- `PublicHolidayId` → `PublicHoliday`.`Id`
- `CompletedBy` → `User`.`Id` or `BusinessUser`.`Id`
- `MondayisedFromReviewId` → `RosterWeekPublicHolidayReview`.`Id` (self-referencing)

---

## Relationships

### Tables That Reference This Table
- **[PublicHolidayReview](../PublicHolidayReview/README.md)** - Per-employee PH observation records
  - Join: `PublicHolidayReview.RosterWeekPHReviewId = RosterWeekPublicHolidayReview.Id`
- **Self-reference** — Mondayized reviews point back to original via `MondayisedFromReviewId`

### Tables This Table References
- **[RosterWeek](../RosterWeek/README.md)** - The roster week
- **[PublicHoliday](../PublicHoliday/README.md)** - The public holiday definition

---

## Entity Actions

- **CreateRosterWeekPublicHolidayReview** - Create a new record
- **CreateOrUpdateRosterWeekPublicHolidayReview** - Upsert
- **UpdateRosterWeekPublicHolidayReview** - Update existing record
- **GetRosterWeekPublicHolidayReview** - Get by Id
- **GetRosterWeekPublicHolidayReviewForUpdate** - Get for update (locking)
- **DeleteRosterWeekPublicHolidayReview** - Delete a record

---

## Mondayisation Self-Reference Pattern

Similar to `PublicHoliday.MondayisedFmPublicHolidayId`, this table has its own Mondayisation link at the review level:

```
Original review:     Id=50, PublicHolidayDate='2025-02-28', MondayisedFromReviewId=NULL
Mondayized review:   Id=51, PublicHolidayDate='2025-03-02', MondayisedFromReviewId=50
```

This allows tracking the review process separately for the original PH date and the Mondayized date, even though they relate to the same holiday event.

---

## Entity Relationship Chain

```
RosterWeek
  └── RosterWeekPublicHolidayReview (week + holiday + review status)
        ├── PublicHoliday (the holiday definition)
        ├── MondayisedFromReviewId → self (links Mondayized to original)
        └── PublicHolidayReview (per employee)
              └── EmployeeWeek → BusinessUser (the employee)
```

---

## Related Tables

- [RosterWeek](../RosterWeek/README.md) - Week definition
- [PublicHoliday](../PublicHoliday/README.md) - Holiday definitions
- [PublicHolidayReview](../PublicHolidayReview/README.md) - Per-employee observations

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-05-24 | Claude + Abdul | Initial documentation for story 3825 |
| 2026-05-24 | Claude + Abdul | Fixed columns from entity screenshot — added PublicHolidayDate, IsComplete, CompletedBy, CompletedAt, WageThreshold, SalaryThreshold, MondayisedFromReviewId |
