-- =============================================
-- Query: Dedup ReportFavourites after Multi-Tenant Off
-- Purpose: Remove duplicate (SupportedReportId, PersonId) rows
--          that appeared when multi-tenant was turned off.
--          Keeps the row with the lowest Id (earliest created),
--          deletes the rest.
-- Run BEFORE adding the unique constraint on (SupportedReportId, PersonId).
-- Target: SQL Server 2014+
-- Story: #3826 — Cross-Tenant Favourites
-- Created: 2026-05-26
-- =============================================

-- Step 1: Preview — show rows that WILL be deleted (run this first to verify)
WITH Ranked AS (
    SELECT
        rf.Id,
        rf.SupportedReportId,
        rf.PersonId,
        rf.BusinessUserId,
        ROW_NUMBER() OVER (
            PARTITION BY rf.SupportedReportId, rf.PersonId
            ORDER BY rf.Id ASC
        ) AS RowNum
    FROM {ReportFavourites} rf
    WHERE rf.PersonId IS NOT NULL
      AND rf.PersonId <> 0
)
SELECT
    Id,
    SupportedReportId,
    PersonId,
    BusinessUserId,
    RowNum
FROM Ranked
WHERE RowNum > 1
ORDER BY SupportedReportId, PersonId;

-- Step 2: Delete duplicates (keep lowest Id per SupportedReportId + PersonId)
-- UNCOMMENT the DELETE below when ready to execute.

-- WITH Ranked AS (
--     SELECT
--         rf.Id,
--         ROW_NUMBER() OVER (
--             PARTITION BY rf.SupportedReportId, rf.PersonId
--             ORDER BY rf.Id ASC
--         ) AS RowNum
--     FROM {ReportFavourites} rf
--     WHERE rf.PersonId IS NOT NULL
--       AND rf.PersonId <> 0
-- )
-- DELETE FROM Ranked
-- WHERE RowNum > 1;

-- Step 3: Verify — should return 0 rows after dedup
-- SELECT
--     SupportedReportId,
--     PersonId,
--     COUNT(*) AS Cnt
-- FROM {ReportFavourites}
-- WHERE PersonId IS NOT NULL AND PersonId <> 0
-- GROUP BY SupportedReportId, PersonId
-- HAVING COUNT(*) > 1;
