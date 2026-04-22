-- =============================================
-- Query: Raw Waste List
-- Purpose: One row per day per site showing waste cost per
--          shift, daily total, and shift completion count.
--          Used by the Raw Waste browse screen.
--          Shows ALL dates in range — LEFT JOINs to
--          RawWasteCount so dates with no data return NULLs.
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2026-04-22
-- =============================================

-- Input Parameters (OutSystems):
--   @SiteIds     VARCHAR   Expand Inline = YES  Comma-separated Site IDs
--   @ConceptId   BIGINT    Expand Inline = NO   Concept for DayParts lookup
--   @StartDate   DATE      Expand Inline = NO   Date range start
--   @EndDate     DATE      Expand Inline = NO   Date range end

WITH
DateList AS (
    SELECT @StartDate AS ReportDate
    UNION ALL
    SELECT DATEADD(DAY, 1, ReportDate)
    FROM DateList
    WHERE ReportDate < @EndDate
),

SiteList AS (
    SELECT s.Id AS SiteId, ISNULL(s.DisplayName, s.Name) AS SiteName
    FROM {Site} s
    WHERE s.Id IN (@SiteIds)
),

Scaffold AS (
    SELECT dl.ReportDate, sl.SiteId, sl.SiteName
    FROM DateList dl
    CROSS JOIN SiteList sl
),

WasteData AS (
    SELECT
        sp.SiteId,
        sp.Date,
        sp.Id AS StockPeriodId,
        SUM(CASE WHEN dp.[Order] = 1 THEN rwc.WasteQty * rwc.CostPerUnit ELSE 0 END) AS OvernightTotal,
        SUM(CASE WHEN dp.[Order] = 2 THEN rwc.WasteQty * rwc.CostPerUnit ELSE 0 END) AS BreakfastTotal,
        SUM(CASE WHEN dp.[Order] = 3 THEN rwc.WasteQty * rwc.CostPerUnit ELSE 0 END) AS DayTotal,
        SUM(CASE WHEN dp.[Order] = 4 THEN rwc.WasteQty * rwc.CostPerUnit ELSE 0 END) AS NightTotal,
        SUM(rwc.WasteQty * rwc.CostPerUnit) AS DailyTotal,
        COUNT(DISTINCT CASE WHEN rwc.WasteQty > 0 THEN dp.Id END) AS ShiftsCompleted
    FROM {StockPeriod} sp
    INNER JOIN {RawWasteCount} rwc ON rwc.StockPeriodId = sp.Id
    INNER JOIN {DayParts} dp ON rwc.DayPartsId = dp.Id AND dp.ConceptId = @ConceptId
    WHERE sp.SiteId IN (@SiteIds)
      AND sp.Date BETWEEN @StartDate AND @EndDate
    GROUP BY sp.SiteId, sp.Date, sp.Id
)

SELECT
    sc.ReportDate AS Date,
    sc.SiteId,
    sc.SiteName,
    wd.StockPeriodId,
    ISNULL(wd.OvernightTotal, 0) AS OvernightTotal,
    ISNULL(wd.BreakfastTotal, 0) AS BreakfastTotal,
    ISNULL(wd.DayTotal, 0) AS DayTotal,
    ISNULL(wd.NightTotal, 0) AS NightTotal,
    ISNULL(wd.DailyTotal, 0) AS DailyTotal,
    ISNULL(wd.ShiftsCompleted, 0) AS ShiftsCompleted,
    (SELECT COUNT(*) FROM {DayParts} d WHERE d.ConceptId = @ConceptId) AS TotalShifts
FROM Scaffold sc
LEFT JOIN WasteData wd ON sc.ReportDate = wd.Date AND sc.SiteId = wd.SiteId
ORDER BY sc.ReportDate DESC
OPTION (MAXRECURSION 1000)
