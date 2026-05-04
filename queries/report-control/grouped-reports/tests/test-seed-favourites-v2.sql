-- =============================================
-- Seed: ReportFavourites — test favourites for Abdul Haseeb
-- Purpose: Add test favourite rows to verify IsFavourite flag
-- BusinessUserId: 317646 (Abdul Haseeb)
-- Method: Manual add in Service Studio Entity Data
-- =============================================

-- Add these rows in ReportFavourites entity data:
-- ┌─────────────────────────────────┬────────────────┐
-- │ Report (pick from dropdown)     │ BusinessUserId │
-- ├─────────────────────────────────┼────────────────┤
-- │ Cash Sheet                      │ 317646         │
-- │ Daily Labour Activity           │ 317646         │
-- │ Daily Tracking                  │ 317646         │
-- │ Period Tracking                 │ 317646         │
-- └─────────────────────────────────┴────────────────┘

-- VERIFICATION: Run this after seeding to confirm
SELECT
    sr.StructureName AS ReportName,
    rf.BusinessUserId
FROM {ReportFavourites} rf
INNER JOIN {SupportedReport} sr ON sr.Id = rf.SupportedReportId
WHERE rf.BusinessUserId = 317646
ORDER BY sr.StructureName
