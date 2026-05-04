-- =============================================
-- Seed: ReportModules — assign reports to modules
-- Purpose: One-time seed to populate ReportModules from old Module values
-- Method: Cannot INSERT via sandbox — use Server Action or manual entity data
-- =============================================

-- MAPPING REFERENCE:
-- Use this to manually add rows in Service Studio (Entity Data → ReportModules → Add Row)
-- Or build a one-time Server Action with CreateReportModules entity action in a For Each loop

-- ┌─────────────────────────────────┬──────────────┬──────────────────────────┐
-- │ Report (StructureName)          │ MaxtelAppId  │ MaxtelApp Name           │
-- ├─────────────────────────────────┼──────────────┼──────────────────────────┤
-- │ Adjusted Preferred Work Times   │ 7            │ Scheduling               │
-- │ Agreed Minimum Hours            │ 7            │ Scheduling               │
-- │ Daily Labour Activity           │ 7            │ Scheduling               │
-- │ Period StaffSchedule            │ 7            │ Scheduling               │
-- │ Schedule Variance               │ 7            │ Scheduling               │
-- │ Training Plan                   │ 7            │ Scheduling               │
-- │ Weekly Staff Schedule           │ 7            │ Scheduling               │
-- │ Cash Sheet                      │ 23           │ Cash                     │
-- │ Daily Tracking                  │ 23           │ Cash                     │
-- │ Period Tracking                 │ 23           │ Cash                     │
-- │ Birthdays                       │ 14           │ Employee Centre          │
-- │ Employee Listing                │ 14           │ Employee Centre          │
-- │ Payslips                        │ 14           │ Employee Centre          │
-- │ Stock Count                     │ 13           │ Stock Management Module  │
-- │ Stock Variation                 │ 13           │ Stock Management Module  │
-- │ Approvals                       │ 18           │ Reports                  │
-- │ Breaks Report                   │ 18           │ Reports                  │
-- │ Period Timecard                 │ 18           │ Reports                  │
-- └─────────────────────────────────┴──────────────┴──────────────────────────┘

-- SKIPPED:
-- Sales Ledger     — retired per PRD
-- Test             — test report
-- Period Staff Schedule AU — no module assigned

-- VERIFICATION: Run this after seeding to confirm
SELECT
    sr.StructureName,
    ma.Name AS ModuleName,
    ma.Id AS MaxtelAppId
FROM {ReportModules} rm
INNER JOIN {SupportedReport} sr ON sr.Id = rm.SupportedReportId
INNER JOIN {MaxtelApp} ma ON ma.Id = rm.MaxtelAppId
ORDER BY ma.Name, sr.StructureName
