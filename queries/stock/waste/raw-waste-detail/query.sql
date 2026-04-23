-- =============================================
-- Query: Raw Waste Detail
-- Purpose: Cross-tab of wasteable items × shifts for a
--          single day. Each cell shows QTY and VALUE.
--          Used by the Raw Waste detail screen.
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2026-04-22
-- =============================================

-- Input Parameters (OutSystems):
--   @StockPeriodId  BIGINT   Expand Inline = NO   StockPeriod for this day
--   @ConceptId      BIGINT   Expand Inline = NO   Concept for DayParts lookup

SELECT
    li.WrinNumber AS WRIN,
    li.ItemType AS Menu,
    li.ItemName AS Description,
    pi.UnitName AS UOM,

    -- Overnight (Order = 1)
    SUM(CASE WHEN dp.[Order] = 1 THEN rwc.WasteQty ELSE 0 END) AS OvernightQty,
    SUM(CASE WHEN dp.[Order] = 1 THEN rwc.WasteQty * rwc.CostPerUnit ELSE 0 END) AS OvernightValue,

    -- Breakfast (Order = 2)
    SUM(CASE WHEN dp.[Order] = 2 THEN rwc.WasteQty ELSE 0 END) AS BreakfastQty,
    SUM(CASE WHEN dp.[Order] = 2 THEN rwc.WasteQty * rwc.CostPerUnit ELSE 0 END) AS BreakfastValue,

    -- Day (Order = 3)
    SUM(CASE WHEN dp.[Order] = 3 THEN rwc.WasteQty ELSE 0 END) AS DayQty,
    SUM(CASE WHEN dp.[Order] = 3 THEN rwc.WasteQty * rwc.CostPerUnit ELSE 0 END) AS DayValue,

    -- Night (Order = 4)
    SUM(CASE WHEN dp.[Order] = 4 THEN rwc.WasteQty ELSE 0 END) AS NightQty,
    SUM(CASE WHEN dp.[Order] = 4 THEN rwc.WasteQty * rwc.CostPerUnit ELSE 0 END) AS NightValue,

    -- Total (all shifts)
    SUM(rwc.WasteQty) AS TotalQty,
    SUM(rwc.WasteQty * rwc.CostPerUnit) AS TotalValue

FROM {RawWasteCount} rwc
INNER JOIN {LogicalItem} li ON rwc.LogicalItemId = li.Id
INNER JOIN {PhysicalItem} pi ON li.DefaultPhysicalItemId = pi.Id
INNER JOIN {DayParts} dp ON rwc.DayPartsId = dp.Id AND dp.ConceptId = @ConceptId
WHERE rwc.StockPeriodId = @StockPeriodId
GROUP BY li.WrinNumber, li.ItemType, li.ItemName, pi.UnitName
