-- =============================================
-- Test: Get reports assigned to "Admin Review" module
-- Purpose: Identify which reports are in Admin Review to decide mapping
-- =============================================

SELECT
    sr.Id,
    sr.StructureName,
    sr.Module,
    sr.SmartReportTypeUniqueName,
    sr.Is_Active
FROM {SupportedReport} sr
WHERE sr.Module = 'Admin Review'
