-- =============================================
-- Test: Check which column holds the report display name
-- Purpose: StructureName is blank for most reports — find the real name column
-- =============================================

SELECT
    sr.Id,
    sr.StructureName,
    sr.SmartReportTypeUniqueName,
    sr.Module
FROM {SupportedReport} sr
WHERE sr.Is_Active = 1
ORDER BY sr.SmartReportTypeUniqueName
