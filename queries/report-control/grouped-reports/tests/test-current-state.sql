-- =============================================
-- Test: Current state of ReportModules + all active reports
-- Purpose: See what's already seeded and what's missing
-- =============================================

SELECT
    sr.Id AS SupportedReportId,
    sr.StructureName,
    sr.Module AS OldModule,
    rm.MaxtelAppId,
    ma.Name AS MaxtelAppName
FROM {SupportedReport} sr
LEFT JOIN {ReportModules} rm ON rm.SupportedReportId = sr.Id
LEFT JOIN {MaxtelApp} ma ON ma.Id = rm.MaxtelAppId
WHERE sr.Is_Active = 1
ORDER BY sr.StructureName
