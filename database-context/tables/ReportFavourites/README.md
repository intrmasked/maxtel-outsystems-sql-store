# Table: ReportFavourites

**OutSystems Entity**: ReportFavourites
**Module**: Report_CS
**Purpose**: Links a SupportedReport to a Person, storing per-person report favourites for quick access via the slide-over panel and starred report cards. Favourites carry across tenants because they are keyed on PersonId (consistent across tenants), not BusinessUserId (tenant-specific).
**Last Updated**: 2026-05-23

---

## Overview

ReportFavourites is a simple join table that tracks which reports a user has favourited. Favourites are per-person (PersonId), not per-site, per-role, or per-tenant. There is no limit on the number of favourites a user can have.

A Person is consistent across tenants while a BusinessUser changes per tenant — so keying on PersonId means favourites follow the person regardless of which tenant they log into.

**Status**: EXISTING TABLE — created in Story #3786. Schema updated in Story #3826 (PersonId migration).

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | BIGINT | PK, NOT NULL | Auto-generated primary key |
| `SupportedReportId` | BIGINT | FK, NOT NULL | References SupportedReport.Id |
| `PersonId` | BIGINT | NOT NULL | References Person.Id (stored by value, cross-service — Access_CS). **Added in Story #3826.** |
| `BusinessUserId` | BIGINT | FK | References BusinessUser.Id (stored by value, cross-service). **DEPRECATED — kept for migration, will be removed in Prod after migration completes.** |

---

## Key Constraints

### Primary Key
- `Id` - Auto-generated identifier

### Unique Constraints
- Composite unique on (`SupportedReportId`, `PersonId`) — a person can only favourite a report once (regardless of tenant)
- ~~Composite unique on (`SupportedReportId`, `BusinessUserId`)~~ — **REMOVED** in Story #3826, replaced by PersonId-based unique

### Foreign Keys
- `SupportedReportId` → SupportedReport.Id (same module — real FK)
- `PersonId` → Person.Id (cross-service — stored by value, no DB-level FK)
- ~~`BusinessUserId` → BusinessUser.Id~~ — **DEPRECATED**, kept during migration only

---

## Relationships

### Tables This Table References
- **SupportedReport** (Report_CS) - The report being favourited
  - Join: `ReportFavourites.SupportedReportId = SupportedReport.Id`
- **Person** (Access_CS) - The person who favourited it (cross-tenant consistent)
  - Join: `ReportFavourites.PersonId = Person.Id`
- ~~**BusinessUser** (Access_CS)~~ — **DEPRECATED**, use Person instead

---

## Business Rules
- Favourites are stored **per person** (PersonId), not per tenant, site, or role
- A person's favourites carry across all tenants they log into
- **No limit** on number of favourites per person
- Toggle logic: if row exists for (SupportedReportId, PersonId) → DELETE, else → INSERT
- UI optimistically updates star state; reverts on error

---

## Migration Notes (Story #3826)

### Schema Change
1. Add `PersonId` (BIGINT, NOT NULL) column to ReportFavourites
2. Remove unique constraint on (SupportedReportId, BusinessUserId)
3. Add unique constraint on (SupportedReportId, PersonId)
4. BusinessUserId becomes nullable / deprecated — do NOT delete yet

### Data Migration
- Run migration query BEFORE deployment (PersonId is NOT NULL)
- Query: `UPDATE ReportFavourites SET PersonId = bu.PersonId FROM BusinessUser bu WHERE ReportFavourites.BusinessUserId = bu.Id`
- See: `queries/utilities/migrate-favourites-personid/`

### CRUD Changes
- All insert/update/filter operations use PersonId instead of BusinessUserId
- GetReportsForModule: input changes from BusinessUserId → PersonId
- Toggle favourite: match on (SupportedReportId, PersonId)

### Post-Migration Cleanup (Future)
- Remove BusinessUserId column from ReportFavourites entity
- Remove old unique constraint if still present

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-04-24 | Claude | Initial documentation — table not yet created |
| 2026-05-23 | Claude | Story #3826 — Added PersonId, deprecated BusinessUserId, updated constraints and business rules for cross-tenant favourites |
