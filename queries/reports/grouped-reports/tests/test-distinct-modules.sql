-- =============================================
-- Test: Get distinct Module values from SupportedReport
-- Purpose: See all current module groupings to map to MaxtelApp IDs
-- =============================================

SELECT
    sr.Module,
    COUNT(*) AS ReportCount
FROM {SupportedReport} sr
WHERE sr.Is_Active = 1
GROUP BY sr.Module
ORDER BY sr.Module
