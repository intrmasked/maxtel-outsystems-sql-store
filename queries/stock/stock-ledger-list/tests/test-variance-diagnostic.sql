-- =============================================
-- Test: Variance Diagnostic — Why variance when Start=0 and End=0?
-- Purpose: Check raw StockPeriodBalance data for 30-31 March 2026
--          to understand why VarQty is non-zero when counts are 0.
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @StartDate DATE = '2026-03-23';
DECLARE @EndDate DATE = '2026-03-31';

SELECT
    SP.Date,
    LI.ItemName,
    LI.ItemType,
    PI.UnitName,
    PI.PortionsPerUnit,

    -- Raw portions (before division)
    SB.OpenQty,
    SB.StartIsTheo,
    SB.RawWasteQty,
    SB.DeliveredQty,
    SB.TransferQty,
    SB.TheoConsumedQty,
    SB.TheoClosedQty,
    SB.ActualClosedQty,
    SB.CloseQtyIsTheo,
    SB.ItemCostAtClose,

    -- Converted to units
    SB.OpenQty / PI.PortionsPerUnit AS StartUnits,
    SB.TheoClosedQty / PI.PortionsPerUnit AS TheoCloseUnits,
    SB.ActualClosedQty / PI.PortionsPerUnit AS ActualCloseUnits,
    SB.TheoConsumedQty / PI.PortionsPerUnit AS UnitsCPM,

    -- VarQty calculation (what we compute)
    CASE
        WHEN SB.CloseQtyIsTheo = 0
        THEN (SB.ActualClosedQty - SB.TheoClosedQty) / PI.PortionsPerUnit
        ELSE NULL
    END AS VarQty,

    -- Key question: is CloseQtyIsTheo false (0) when it should be true?
    CASE
        WHEN SB.CloseQtyIsTheo = 0 AND SB.ActualClosedQty = 0 AND SB.TheoClosedQty = 0
        THEN 'SUSPECT: Both 0 but CloseQtyIsTheo=false'
        WHEN SB.CloseQtyIsTheo = 0 AND SB.ActualClosedQty = SB.TheoClosedQty
        THEN 'No variance (Actual=Theo)'
        WHEN SB.CloseQtyIsTheo = 0
        THEN 'Real variance'
        ELSE 'Theo (no variance shown)'
    END AS DiagnosticFlag

FROM {StockPeriodBalance} SB
JOIN {StockPeriod} SP    ON SB.StockPeriodId = SP.Id
JOIN {LogicalItem} LI    ON SB.LogicalItemId = LI.Id
JOIN {PhysicalItem} PI   ON LI.DefaultPhysicalItemId = PI.Id
WHERE SP.SiteId = @SiteId
  AND SP.Date BETWEEN @StartDate AND @EndDate
  AND LI.ItemType = 'P'
  AND SB.CloseQtyIsTheo = 0
ORDER BY SP.Date, LI.ItemName
