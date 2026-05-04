-- =============================================
-- Seed: INSERT ReportModules rows
-- Purpose: Bulk seed ReportModules from old SupportedReport.Module values
-- Note: May not work in sandbox (INSERT restrictions) — try it and see
-- =============================================

INSERT INTO {ReportModules} (SupportedReportId, MaxtelAppId)
SELECT
    sr.Id,
    CASE sr.Module
        WHEN 'Scheduling'       THEN 7   -- Scheduling
        WHEN 'Cash'             THEN 23  -- Cash
        WHEN 'Employee Centre'  THEN 14  -- Employee Centre
        WHEN 'Stock Count'      THEN 13  -- Stock Management Module
        WHEN 'Admin Review'     THEN 18  -- Reports
    END
FROM {SupportedReport} sr
WHERE sr.Is_Active = 1
  AND sr.Module IN ('Scheduling', 'Cash', 'Employee Centre', 'Stock Count', 'Admin Review')
  AND sr.Id NOT IN (SELECT SupportedReportId FROM {ReportModules})
