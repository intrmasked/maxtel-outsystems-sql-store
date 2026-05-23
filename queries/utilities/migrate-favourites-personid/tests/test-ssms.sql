-- =============================================
-- Test: Migrate ReportFavourites — SSMS Version
-- Purpose: Run in SSMS sandbox to verify migration logic
-- Story: #3826 — Cross-Tenant Favourites
-- =============================================

-- Preview what the migration WOULD do (read-only check)
SELECT
    rf.Id AS FavouriteId,
    rf.SupportedReportId,
    rf.BusinessUserId,
    bu.PersonId AS PersonId_ToSet,
    p.Name AS PersonName,
    -- Verification stats via window functions
    COUNT(*) OVER() AS Total_Rows,
    SUM(CASE WHEN bu.PersonId IS NOT NULL AND bu.PersonId <> 0 THEN 1 ELSE 0 END) OVER() AS Rows_With_Valid_Person,
    SUM(CASE WHEN bu.PersonId IS NULL OR bu.PersonId = 0 THEN 1 ELSE 0 END) OVER() AS Rows_Without_Valid_Person
FROM {ReportFavourites} rf
LEFT JOIN {BusinessUser} bu ON rf.BusinessUserId = bu.Id
LEFT JOIN {Person} p ON bu.PersonId = p.Id
ORDER BY rf.Id;
