-- =============================================
-- Test: Get report IDs as integers for seeding ReportFavourites
-- Purpose: Get raw numeric IDs we can use to add favourite rows
-- =============================================

SELECT
    sr.StructureName,
    rm.SupportedReportId
FROM {ReportModules} rm
INNER JOIN {SupportedReport} sr ON sr.Id = rm.SupportedReportId
WHERE sr.Is_Active = 1
ORDER BY sr.StructureName
