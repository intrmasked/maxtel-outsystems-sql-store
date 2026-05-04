-- =============================================
-- Test: Verify ReportModules seed — force all text columns to show
-- =============================================

SELECT
    ISNULL(sr.StructureName, '') AS ReportName,
    sr.Module AS OldModule,
    ma.Name AS ModuleName
FROM {ReportModules} rm
INNER JOIN {SupportedReport} sr ON sr.Id = rm.SupportedReportId
INNER JOIN {MaxtelApp} ma ON ma.Id = rm.MaxtelAppId
ORDER BY ma.Name, sr.StructureName
