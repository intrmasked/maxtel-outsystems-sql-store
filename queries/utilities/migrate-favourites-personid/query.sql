-- =============================================
-- Query: Migrate ReportFavourites — Populate PersonId
-- Purpose: Backfill PersonId from BusinessUser.PersonId
--          for all existing ReportFavourites rows.
--          Run BEFORE deployment (PersonId is NOT NULL).
-- Target: SQL Server 2014+
-- Story: #3826 — Cross-Tenant Favourites
-- Created: 2026-05-23
-- =============================================

-- Step 1: Backfill PersonId from BusinessUser
UPDATE rf
SET rf.PersonId = bu.PersonId
FROM {ReportFavourites} rf
INNER JOIN {BusinessUser} bu ON rf.BusinessUserId = bu.Id
WHERE rf.PersonId IS NULL
   OR rf.PersonId = 0;

-- Step 2: Verify — check for any rows that couldn't be migrated
-- (BusinessUserId doesn't match a valid BusinessUser)
SELECT
    rf.Id,
    rf.SupportedReportId,
    rf.BusinessUserId,
    rf.PersonId
FROM {ReportFavourites} rf
WHERE rf.PersonId IS NULL
   OR rf.PersonId = 0;
