-- =============================================
-- Test: Seed ReportModules from existing SupportedReport.Module values
-- Purpose: One-time migration of old Module text field to ReportModules join table
-- Status: REFERENCE ONLY — frontend Report Settings UI now handles module assignments
-- Note: Module names on the new UI differ from old values (e.g. "Scheduling" → "Schedules")
--        Use this only if you need a baseline seed before the UI is ready
-- =============================================

-- Step 1: Check what needs mapping
SELECT
    sr.Id AS SupportedReportId,
    sr.StructureName,
    sr.Module AS OldModuleValue,
    CASE sr.Module
        WHEN 'Scheduling' THEN 7       -- MaxtelApp: Scheduling
        WHEN 'Cash'       THEN 23      -- MaxtelApp: Cash
        WHEN 'Employee Centre' THEN 14  -- MaxtelApp: Employee Centre
        WHEN 'Stock Count' THEN 13      -- MaxtelApp: Stock Management Module
        WHEN 'Admin Review' THEN NULL   -- TODO: No matching MaxtelApp — needs decision
        ELSE NULL
    END AS MaxtelAppId
FROM {SupportedReport} sr
WHERE sr.Is_Active = 1
  AND sr.Module IS NOT NULL
  AND sr.Module <> ''
ORDER BY sr.Module, sr.StructureName

-- =============================================
-- NOTE: Do NOT run the INSERT below in sandbox — it's for reference only.
-- The Report Settings UI (screenshot 2026-04-24) handles module assignments
-- with a different grouping scheme (Daily Shift, Schedules, Accounting, etc.)
-- =============================================

-- INSERT INTO {ReportModules} (SupportedReportId, MaxtelAppId)
-- SELECT
--     sr.Id,
--     CASE sr.Module
--         WHEN 'Scheduling' THEN 7
--         WHEN 'Cash'       THEN 23
--         WHEN 'Employee Centre' THEN 14
--         WHEN 'Stock Count' THEN 13
--     END
-- FROM {SupportedReport} sr
-- WHERE sr.Is_Active = 1
--   AND sr.Module IN ('Scheduling', 'Cash', 'Employee Centre', 'Stock Count')
