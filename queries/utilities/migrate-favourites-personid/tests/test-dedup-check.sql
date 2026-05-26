-- =============================================
-- Test: Check for duplicate (SupportedReportId, PersonId) rows
-- Purpose: After multi-tenant was turned off, rows from different
--          tenants are now visible together. Same person may have
--          favourited the same report in multiple tenants, creating
--          duplicates that block the unique constraint.
-- Run this FIRST (read-only) to see what duplicates exist.
-- Target: SQL Server 2014+
-- Story: #3826
-- Created: 2026-05-26
-- =============================================

-- Show duplicate groups: which (SupportedReportId, PersonId) combos have more than 1 row
SELECT
    rf.SupportedReportId,
    rf.PersonId,
    COUNT(*) AS DuplicateCount,
    MIN(rf.Id) AS KeepId,
    STRING_AGG(CAST(rf.Id AS VARCHAR), ', ') AS AllIds
FROM {ReportFavourites} rf
WHERE rf.PersonId IS NOT NULL
  AND rf.PersonId <> 0
GROUP BY rf.SupportedReportId, rf.PersonId
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;
