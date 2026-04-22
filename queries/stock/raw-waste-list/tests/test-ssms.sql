-- =============================================
-- Test: Raw Waste List (SSMS)
-- Purpose: Verify query returns one row per day
--          including dates with no RawWasteCount data
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @ConceptId BIGINT = 129;
DECLARE @StartDate DATE = '2026-04-15';
DECLARE @EndDate DATE = '2026-04-22';

WITH
DateList AS (
    SELECT @StartDate AS ReportDate
    UNION ALL
    SELECT DATEADD(DAY, 1, ReportDate)
    FROM DateList
    WHERE ReportDate < @EndDate
),

WasteData AS (
    SELECT
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
    WHERE sp.SiteId = @SiteId
      AND sp.Date BETWEEN @StartDate AND @EndDate
    GROUP BY sp.Date, sp.Id
)

SELECT
    dl.ReportDate AS Date,
    wd.StockPeriodId,
    ISNULL(wd.OvernightTotal, 0) AS OvernightTotal,
    ISNULL(wd.BreakfastTotal, 0) AS BreakfastTotal,
    ISNULL(wd.DayTotal, 0) AS DayTotal,
    ISNULL(wd.NightTotal, 0) AS NightTotal,
    ISNULL(wd.DailyTotal, 0) AS DailyTotal,
    ISNULL(wd.ShiftsCompleted, 0) AS ShiftsCompleted,
    (SELECT COUNT(*) FROM {DayParts} d WHERE d.ConceptId = @ConceptId) AS TotalShifts
FROM DateList dl
LEFT JOIN WasteData wd ON dl.ReportDate = wd.Date
ORDER BY dl.ReportDate DESC
OPTION (MAXRECURSION 1000)
