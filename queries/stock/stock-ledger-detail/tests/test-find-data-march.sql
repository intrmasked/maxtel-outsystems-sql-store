-- =============================================
-- Test: Find StockPeriodBalance data for 29-30 March 2026
-- Purpose: Check if any stock data exists for recent dates
--          so we can test GetRawStockDetail with real data.
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @StartDate DATE = '2026-03-29';
DECLARE @EndDate DATE = '2026-03-30';

SELECT
    SP.Date,
    SP.SiteId,
    SP.StockPeriodStatusId,
    SB.LogicalItemId,
    LI.ItemName,
    LI.ItemType,
    SB.OpenQty,
    SB.DeliveredQty,
    SB.TransferQty,
    SB.RawWasteQty,
    SB.TheoConsumedQty,
    SB.TheoClosedQty,
    SB.ActualClosedQty,
    SB.CloseQtyIsActual,
    SB.StartIsTheo,
    SB.ItemCostAtClose,
    -- Diagnostic: how many items exist per date
    COUNT(*) OVER(PARTITION BY SP.Date) AS ItemsOnDate,
    -- Diagnostic: how many distinct dates have data
    DENSE_RANK() OVER(ORDER BY SP.Date) + DENSE_RANK() OVER(ORDER BY SP.Date DESC) - 1 AS DatesWithData,
    -- Diagnostic: total rows
    COUNT(*) OVER() AS TotalRows
FROM {StockPeriodBalance} SB
JOIN {StockPeriod} SP    ON SB.StockPeriodId = SP.Id
JOIN {LogicalItem} LI    ON SB.LogicalItemId = LI.Id
WHERE SP.SiteId = @SiteId
  AND SP.Date BETWEEN @StartDate AND @EndDate
ORDER BY SP.Date, LI.ItemName
