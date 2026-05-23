# Query: Migrate ReportFavourites — Populate PersonId

**Story**: [#3826 — Cross-Tenant Favourites](https://dev.azure.com/MaxtelNZ/Scheduling/_workitems/edit/3826)
**Category**: Utility / Data Migration
**Created**: 2026-05-23

---

## Purpose

Backfills the new `PersonId` column on `ReportFavourites` by looking up `BusinessUser.PersonId` for each existing row. This migration must run **before deployment** because `PersonId` is NOT NULL.

## When to Run

1. **Add PersonId column** to ReportFavourites in OutSystems (nullable initially in DB, even though logically NOT NULL)
2. **Run this migration** in Prod to populate PersonId for all existing rows
3. **Verify** no rows have NULL/0 PersonId (Step 2 of query returns orphans)
4. **Deploy** the new code that uses PersonId for all CRUD operations

## How It Works

1. `UPDATE` joins ReportFavourites → BusinessUser to copy `bu.PersonId` into `rf.PersonId`
2. Only updates rows where PersonId is NULL or 0 (safe to re-run)
3. Verification SELECT shows any rows that couldn't be migrated (orphaned BusinessUserIds)

## Tables Used

| Table | Purpose |
|-------|---------|
| ReportFavourites | Target — receives PersonId |
| BusinessUser | Source — provides PersonId via BusinessUserId lookup |

## Files

| File | Purpose |
|------|---------|
| `query.sql` | Production migration (OutSystems `{Table}` format) |
| `tests/test-ssms.sql` | Read-only preview for SSMS sandbox — shows what migration would do |

## Post-Migration

After verifying all rows have valid PersonId:
- Update unique constraint: remove `(SupportedReportId, BusinessUserId)`, add `(SupportedReportId, PersonId)`
- Deploy new CRUD logic using PersonId
- BusinessUserId column can be removed in a future cleanup
