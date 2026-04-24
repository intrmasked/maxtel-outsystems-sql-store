# Table: ReportFavourites

**OutSystems Entity**: ReportFavourites
**Module**: Report_CS
**Purpose**: Links a SupportedReport to a BusinessUser, storing per-login report favourites for quick access via the slide-over panel and starred report cards.
**Last Updated**: 2026-04-24

---

## Overview

ReportFavourites is a simple join table that tracks which reports a user has favourited. Favourites are per-login (BusinessUser), not per-site or per-role. There is no limit on the number of favourites a user can have.

**Status**: NEW TABLE — needs to be created in OutSystems (Story #3786 / Feature 2.2).

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | BIGINT | PK, NOT NULL | Auto-generated primary key |
| `SupportedReportId` | BIGINT | FK, NOT NULL | References SupportedReport.Id |
| `BusinessUserId` | BIGINT | FK, NOT NULL | References BusinessUser.Id (stored by value, no cross-service FK) |

---

## Key Constraints

### Primary Key
- `Id` - Auto-generated identifier

### Unique Constraints
- Composite unique on (`SupportedReportId`, `BusinessUserId`) — a user can only favourite a report once

### Foreign Keys
- `SupportedReportId` → SupportedReport.Id (same module — real FK)
- `BusinessUserId` → BusinessUser.Id (cross-service — stored by value, no DB-level FK)

---

## Relationships

### Tables This Table References
- **SupportedReport** - The report being favourited
  - Join: `ReportFavourites.SupportedReportId = SupportedReport.Id`
- **BusinessUser** (Access_CS) - The user who favourited it
  - Join: `ReportFavourites.BusinessUserId = BusinessUser.Id`

---

## Business Rules
- Favourites are stored **per login** (BusinessUserId), not per site or role
- **No limit** on number of favourites per user
- Toggle logic: if row exists → DELETE, else → INSERT (handled by entity actions in OutSystems)
- UI optimistically updates star state; reverts on error

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-04-24 | Claude | Initial documentation — table not yet created |
