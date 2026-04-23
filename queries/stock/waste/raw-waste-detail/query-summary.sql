-- =============================================
-- Query: Raw Waste Detail — Summary Strip
-- Purpose: Single row with per-shift totals for a day.
--          Used by the summary strip at the top of the
--          Raw Waste detail screen.
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2026-04-22
-- =============================================

-- Input Parameters (OutSystems):
--   @StockPeriodId  BIGINT   Expand Inline = NO   StockPeriod for this day
--   @ConceptId      BIGINT   Expand Inline = NO   Concept for DayParts lookup

SELECT
    SUM(CASE WHEN dp.[Order] = 1 THEN rwc.WasteQty * rwc.CostPerUnit ELSE 0 END) AS OvernightTotal,
    SUM(CASE WHEN dp.[Order] = 2 THEN rwc.WasteQty * rwc.CostPerUnit ELSE 0 END) AS BreakfastTotal,
    SUM(CASE WHEN dp.[Order] = 3 THEN rwc.WasteQty * rwc.CostPerUnit ELSE 0 END) AS DayTotal,
    SUM(CASE WHEN dp.[Order] = 4 THEN rwc.WasteQty * rwc.CostPerUnit ELSE 0 END) AS NightTotal,
    SUM(rwc.WasteQty * rwc.CostPerUnit) AS DailyTotal,
    COUNT(DISTINCT CASE WHEN rwc.WasteQty > 0 THEN dp.Id END) AS ShiftsCompleted,
    (SELECT COUNT(*) FROM {DayParts} d WHERE d.ConceptId = @ConceptId) AS TotalShifts
FROM {RawWasteCount} rwc
INNER JOIN {DayParts} dp ON rwc.DayPartsId = dp.Id AND dp.ConceptId = @ConceptId
WHERE rwc.StockPeriodId = @StockPeriodId
