-- =============================================
-- Test: Get all MaxtelApp rows
-- Purpose: See all available module IDs to map SupportedReport.Module values
-- =============================================

SELECT
    ma.Id,
    ma.Name,
    ma.Description,
    ma.IsMaxtelControlled
FROM {MaxtelApp} ma
ORDER BY ma.Name
