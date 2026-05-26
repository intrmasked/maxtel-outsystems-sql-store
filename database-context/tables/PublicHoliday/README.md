# Table: PublicHoliday

**OutSystems Entity**: PublicHoliday
**Module**: RosterManagement_CS
**Database Table**: {PublicHoliday}
**Purpose**: Stores public holiday definitions — dates, names, and Mondayisation info.
**Last Updated**: 2026-05-24

---

## Overview

PublicHoliday defines the actual public holiday calendar. Each record is a single holiday date. When a PH falls on a weekend and gets Mondayized, a **second record** is created for the Monday date, with `MondayisedFmPublicHolidayId` pointing back to the original weekend PH record.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | BIGINT | PK, NOT NULL | Primary key, auto-increment |
| `Name` | VARCHAR | NOT NULL | Holiday name (e.g., "Waitangi Day") |
| `Date` | DATE | NOT NULL | The date of the public holiday |
| `CountryCode` | VARCHAR | NOT NULL | Country code (e.g., "NZ") — determines which country this PH applies to |
| `ProvinceId` | BIGINT | FK | Links to Province — for regional/provincial holidays (e.g., Anniversary Days) |
| `IsMondayisable` | BIT | NOT NULL | Whether this PH **can** be Mondayized if it falls on a weekend |
| `MondayisedFmPublicHolidayId` | BIGINT | FK (self) | Self-referencing FK — if this is a Mondayized record, points to the original weekend PH record. `NULL` or `0` for original/non-Mondayized holidays |

---

## Key Constraints

### Primary Key
- `Id` - Unique identifier

### Foreign Keys
- `ProvinceId` → Province table
- `MondayisedFmPublicHolidayId` → `PublicHoliday`.`Id` (self-referencing)

---

## Relationships

### Tables That Reference This Table
- **Self-reference** — Mondayized records point back to original PH via `MondayisedFmPublicHolidayId`
- **[RosterWeekPublicHolidayReview](../RosterWeekPublicHolidayReview/README.md)** — Week-level PH review links to this table

### Self-Referencing Pattern
```
Original PH:     Id=100, Date='2025-02-28' (Sat), IsMondayisable=1, MondayisedFmPublicHolidayId=NULL
Mondayized PH:   Id=101, Date='2025-03-02' (Mon), IsMondayisable=0, MondayisedFmPublicHolidayId=100
```

---

## Business Logic: Mondayised Holidays

- `IsMondayisable = 1` means the PH **can** be Mondayized if it falls on Sat/Sun
- When Mondayized, a new PublicHoliday record is created for the Monday with `MondayisedFmPublicHolidayId` pointing to the original
- The original record stays as-is — it represents the actual calendar PH date
- `PublicHolidayReview` then determines per-employee which date they observe

### How to identify Mondayized records
```sql
-- Original PH (not a Mondayized copy)
WHERE MondayisedFmPublicHolidayId IS NULL OR MondayisedFmPublicHolidayId = 0

-- Mondayized copy (the Monday replacement)
WHERE MondayisedFmPublicHolidayId > 0
```

---

## Common Query Patterns

### Get public holidays for a date range
```sql
SELECT Id, Name, Date, IsMondayisable, MondayisedFmPublicHolidayId
FROM {PublicHoliday}
WHERE Date BETWEEN @StartDate AND @EndDate
```

### Get a Mondayized pair
```sql
-- Get original + its Mondayized version
SELECT ph.Id, ph.Name, ph.Date, 'Original' AS Type
FROM {PublicHoliday} ph
WHERE ph.Id = @PublicHolidayId
UNION ALL
SELECT ph2.Id, ph2.Name, ph2.Date, 'Mondayized' AS Type
FROM {PublicHoliday} ph2
WHERE ph2.MondayisedFmPublicHolidayId = @PublicHolidayId
```

---

## Related Tables

- [RosterWeekPublicHolidayReview](../RosterWeekPublicHolidayReview/README.md) - Week-level PH review
- [PublicHolidayReview](../PublicHolidayReview/README.md) - Per-employee PH observations (links via HolidayDate, not FK)

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-05-24 | Claude + Abdul | Initial documentation for story 3825 |
| 2026-05-24 | Claude + Abdul | Fixed columns from entity screenshot — replaced IsMondayized with IsMondayisable, removed SiteId, added CountryCode, ProvinceId, MondayisedFmPublicHolidayId |
