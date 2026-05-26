# Session: Cross-Tenant Favourites (PersonId Migration) — 2026-05-23

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_workitems/edit/3826
**PRD:** See prd.md in this folder
**Mock:** _(not provided)_

## Original Story/Requirements

> A change is required to ReportFavourites so that Favourites carry across tenants.
> Currently the table maps SupportedReports to BusinessUsers. A new field needs to be
> added for PersonId. A person is consistent across tenants while a businessuser changes.
> The BusinessUser field will be effectively deprecated but we won't delete it yet
> (will need to in Prod for a migration).
>
> Following changes:
> 1. Update the schema (add PersonId to ReportFavourites)
> 2. Update CRUD operations on the table to insert/update based on a Person rather than a Business User
> 3. Update all uses to filter based on PersonId rather than BusinessUserId
> 4. Write a manual SQL query that will take existing records and populate the PersonId field (run in Prod to migrate data)

## Status
- [ ] Complete / [X] In Progress / [ ] Needs Review
- Current step: Tasks 1–4 done (table docs, migration, multi-tenant off, dedup, unique constraint). Next: CRUD changes documentation.

## Context

### Why PersonId?
- `BusinessUser` is **tenant-specific** — a person gets a different BusinessUserId in each tenant
- `Person` is **consistent across tenants** — same PersonId everywhere
- Favourites should follow the person, not the tenant-specific login
- This mirrors the SiteFavourite pattern where cross-tenant support was needed

### Current State
- `ReportFavourites` has: Id (PK), SupportedReportId (FK), BusinessUserId (FK)
- Unique constraint on (SupportedReportId, BusinessUserId)
- CRUD uses BusinessUserId for insert/filter/delete
- `GetReportsForModule` takes BusinessUserId input, LEFT JOINs ReportFavourites

### Target State
- `ReportFavourites` adds: PersonId (BIGINT, NOT NULL, FK to Person.Id)
- BusinessUserId kept but deprecated (not deleted yet — needed for prod migration)
- Unique constraint changes to (SupportedReportId, PersonId), old one removed after migration
- All CRUD operations use PersonId instead of BusinessUserId
- `GetReportsForModule` takes PersonId input, filters by PersonId
- Migration query populates PersonId from BusinessUser.PersonId for existing rows

## Key Decisions
- **PersonId = NOT NULL** — migration runs before deployment, all rows must have PersonId
- **Replace unique constraint** — old (SupportedReportId, BusinessUserId) removed, new (SupportedReportId, PersonId) added
- **BusinessUserId kept during transition** — will be removed after prod migration completes

## Task Progress

### Task 1: Update Table Documentation ✅
- Updated `database-context/tables/ReportFavourites/README.md` — added PersonId, deprecated BusinessUserId, updated constraints/rules
- Created `database-context/tables/Person/README.md` — new table docs from Service Studio screenshot

### Task 2: Write Migration SQL Query ✅
- Created `queries/utilities/migrate-favourites-personid/`
  - `query.sql` — UPDATE to backfill PersonId from BusinessUser.PersonId + verification SELECT
  - `tests/test-ssms.sql` — read-only preview showing what migration would do
  - `README.md` — purpose, when to run, how it works
  - `metadata.json` — standard metadata

### Task 3: Multi-Tenant Off + Dedup ✅
- Turned Multi-Tenant = No on ReportFavourites entity in OutSystems (so favourites are visible across tenants)
- Ran dedup query to remove duplicate `(SupportedReportId, PersonId)` rows caused by tenant isolation removal
- Added unique constraint `OSUNIQ_ReportFavourites_SupportedReportPersonId` on `(SupportedReportId, PersonId)`
- Old `(SupportedReportId, BusinessUserId)` unique constraint removed
- Dedup query: `queries/utilities/migrate-favourites-personid/dedup.sql`

### Task 4: Document CRUD Operation Changes ⬜ (Next)
- Toggle favourite: use PersonId instead of BusinessUserId
- GetReportsForModule: input changes from BusinessUserId → PersonId, filter by PersonId
- Document what changes in OutSystems Server/Service Actions

## Tables Documentation
- `ReportFavourites` — **UPDATED** (PersonId added, BusinessUserId deprecated)
- `BusinessUser` — **EXISTING** (has PersonId FK to Person)
- `Person` — **CREATED** (new table docs from screenshot)
- `SupportedReport` — **EXISTING** (no changes)

## Files Created/Modified

| File | Action | Purpose |
|------|--------|---------|
| `database-context/tables/ReportFavourites/README.md` | Modified | Added PersonId, deprecated BusinessUserId |
| `database-context/tables/Person/README.md` | Created | New table docs |
| `queries/utilities/migrate-favourites-personid/query.sql` | Created | Production migration query |
| `queries/utilities/migrate-favourites-personid/tests/test-ssms.sql` | Created | SSMS sandbox preview |
| `queries/utilities/migrate-favourites-personid/README.md` | Created | Query documentation |
| `queries/utilities/migrate-favourites-personid/metadata.json` | Created | Query metadata |
| `queries/utilities/migrate-favourites-personid/dedup.sql` | Created | Dedup query for post-multi-tenant-off cleanup |
| `queries/utilities/migrate-favourites-personid/tests/test-dedup-check.sql` | Created | Read-only duplicate check |

## Git Commits
- `feat(report-favourites): Add PersonId for cross-tenant favourites — schema, migration, table docs` (on main)
- _(dedup + session update commit pending)_

## Next Steps
1. Task 4 — Document CRUD operation changes (what to update in OutSystems)
