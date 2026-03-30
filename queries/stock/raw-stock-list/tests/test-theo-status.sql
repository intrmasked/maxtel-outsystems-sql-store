-- =============================================
-- Test: Theo Status Diagnostic
-- Purpose: Check CloseQtyIsTheo distribution across all data
--          to understand why variance columns show NULL/blank.
--          Variance only calculates when CloseQtyIsTheo = false
--          (actual physical count entered via count entry flow).
--
-- Spec reference (Section 10 - Total Variance Card):
--   "Only rows where CloseQtyIsTheo = false for their
--    last-period StockPeriodBalance qualify."
--
-- Spec reference (Section 3 - Derived fields):
--   Var Qty/$/% = blank when CloseQtyIsTheo = true
--
-- Spec reference (Section 4 - Step 3):
--   CloseQtyIsTheo = true (default — until actual count
--   is entered via the count entry flow)
--   ActualClosedQty = null
-- =============================================

DECLARE @SiteIds VARCHAR(100) = '3187';
DECLARE @StartDate DATE = '2026-03-28';
DECLARE @EndDate DATE = '2026-03-29';

SELECT
    SP.SiteId,
    SP.Date,
    SB.CloseQtyIsTheo,
    SB.StartIsTheo,
    COUNT(*) AS ItemCount,

    -- How many have actual close values
    SUM(CASE WHEN SB.ActualClosedQty IS NOT NULL THEN 1 ELSE 0 END) AS HasActualClose,
    SUM(CASE WHEN SB.ActualClosedQty IS NULL THEN 1 ELSE 0 END) AS MissingActualClose,

    -- Variance readiness: only rows with CloseQtyIsTheo = false qualify
    SUM(CASE WHEN SB.CloseQtyIsTheo = 0 AND SB.ActualClosedQty IS NOT NULL THEN 1 ELSE 0 END) AS VarianceReady,

    -- Sample values for sanity check
    MIN(SB.TheoClosedQty) AS MinTheoClose,
    MAX(SB.TheoClosedQty) AS MaxTheoClose,
    MIN(SB.ActualClosedQty) AS MinActualClose,
    MAX(SB.ActualClosedQty) AS MaxActualClose,
    MIN(SB.ItemCostAtClose) AS MinCost,
    MAX(SB.ItemCostAtClose) AS MaxCost

FROM {StockPeriodBalance} SB
JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
WHERE SP.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
  AND SP.Date BETWEEN @StartDate AND @EndDate
GROUP BY SP.SiteId, SP.Date, SB.CloseQtyIsTheo, SB.StartIsTheo
ORDER BY SP.SiteId, SP.Date, SB.CloseQtyIsTheo, SB.StartIsTheo
