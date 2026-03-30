-- =============================================
-- Test: GetRawStockDetail — SSMS sandbox version
-- Purpose: Full query with DECLARE params for local testing
-- Target: SQL Server 2016+ (SSMS)
-- Updated: 2026-03-30 — Removed item metadata (now in separate query)
-- =============================================

DECLARE @SiteId          BIGINT = 3187;
DECLARE @StartDate       DATE = '2026-03-29';
DECLARE @EndDate         DATE = '2026-03-30';
DECLARE @LogicalItemId   BIGINT = 1;              -- Change to a valid LogicalItemId

WITH

-- [CTE 1]: Get PortionsPerUnit for unit conversion
ItemUnit AS (
    SELECT
        LI.Id              AS LogicalItemId,
        PI.PortionsPerUnit
    FROM {LogicalItem} LI
    JOIN {PhysicalItem} PI ON LI.DefaultPhysicalItemId = PI.Id
    WHERE LI.Id = @LogicalItemId
),

-- [CTE 2]: Date boundaries for this item in range
Bounds AS (
    SELECT
        MIN(SP.Date) AS FirstDate,
        MAX(SP.Date) AS LastDate
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    WHERE SB.LogicalItemId = @LogicalItemId
      AND SP.SiteId = @SiteId
      AND SP.Date BETWEEN @StartDate AND @EndDate
),

-- [CTE 3]: Daily rows
DailyData AS (
    SELECT
        SP.Date              AS ReportDate,
        SB.OpenQty           / IU.PortionsPerUnit   AS StartingCount,
        SB.StartIsTheo,
        CAST(SB.RawWasteQty AS DECIMAL(18,4))      / IU.PortionsPerUnit   AS RawWaste,
        CAST(SB.DeliveredQty AS DECIMAL(18,4))     / IU.PortionsPerUnit   AS Deliveries,
        CAST(SB.TransferQty AS DECIMAL(18,4))      / IU.PortionsPerUnit   AS Transfers,
        CAST(SB.TheoConsumedQty AS DECIMAL(18,4))  / IU.PortionsPerUnit   AS UnitsCPM,
        CASE
            WHEN SB.CloseQtyIsTheo = 0
            THEN SB.ActualClosedQty / IU.PortionsPerUnit
            ELSE SB.TheoClosedQty   / IU.PortionsPerUnit
        END AS EndCount,
        SB.CloseQtyIsTheo,
        CASE
            WHEN SB.CloseQtyIsTheo = 0
            THEN (SB.ActualClosedQty - SB.TheoClosedQty) / IU.PortionsPerUnit
            ELSE NULL
        END AS VarQty,
        CASE
            WHEN SB.CloseQtyIsTheo = 0
            THEN ((SB.ActualClosedQty - SB.TheoClosedQty) / IU.PortionsPerUnit)
                 * SB.ItemCostAtClose
            ELSE NULL
        END AS VarDollar,
        CASE
            WHEN SB.CloseQtyIsTheo = 0 AND SB.TheoConsumedQty <> 0
            THEN ((SB.ActualClosedQty - SB.TheoClosedQty) / SB.TheoConsumedQty) * 100
            ELSE NULL
        END AS VarPercent,
        SB.ItemCostAtClose
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    JOIN ItemUnit IU       ON SB.LogicalItemId = IU.LogicalItemId
    WHERE SB.LogicalItemId = @LogicalItemId
      AND SP.SiteId = @SiteId
      AND SP.Date BETWEEN @StartDate AND @EndDate
),

-- [CTE 4]: First and last row values for Total row
FirstRow AS (
    SELECT StartingCount, StartIsTheo
    FROM DailyData
    WHERE ReportDate = (SELECT FirstDate FROM Bounds)
),
LastRow AS (
    SELECT EndCount, CloseQtyIsTheo, VarQty, VarDollar
    FROM DailyData
    WHERE ReportDate = (SELECT LastDate FROM Bounds)
),

-- [CTE 5]: Combine Total + Detail rows
AllRows AS (
    -- Total row
    SELECT
        'Total'          AS RowType,
        NULL             AS ReportDate,
        FR.StartingCount,
        FR.StartIsTheo,
        SUM(DD.RawWaste)    AS RawWaste,
        SUM(DD.Deliveries)  AS Deliveries,
        SUM(DD.Transfers)   AS Transfers,
        SUM(DD.UnitsCPM)    AS UnitsCPM,
        LR.EndCount,
        LR.CloseQtyIsTheo,
        LR.VarQty,
        LR.VarDollar,
        CASE
            WHEN SUM(CASE WHEN DD.CloseQtyIsTheo = 0 THEN DD.UnitsCPM ELSE 0 END) = 0 THEN NULL
            ELSE SUM(CASE WHEN DD.CloseQtyIsTheo = 0 THEN DD.VarQty ELSE 0 END)
                 / SUM(CASE WHEN DD.CloseQtyIsTheo = 0 THEN DD.UnitsCPM ELSE 0 END) * 100
        END AS VarPercent,
        NULL             AS ItemCostAtClose
    FROM DailyData DD
    CROSS JOIN FirstRow FR
    CROSS JOIN LastRow LR
    GROUP BY FR.StartingCount, FR.StartIsTheo,
             LR.EndCount, LR.CloseQtyIsTheo, LR.VarQty, LR.VarDollar

    UNION ALL

    -- Detail rows
    SELECT
        'Detail'         AS RowType,
        ReportDate,
        StartingCount, StartIsTheo,
        RawWaste, Deliveries, Transfers, UnitsCPM,
        EndCount, CloseQtyIsTheo,
        VarQty, VarDollar, VarPercent,
        ItemCostAtClose
    FROM DailyData
)

SELECT
    RowType,
    ReportDate,
    StartingCount,
    StartIsTheo,
    RawWaste,
    Deliveries,
    Transfers,
    UnitsCPM,
    EndCount,
    CloseQtyIsTheo,
    VarQty,
    VarDollar,
    VarPercent,
    ItemCostAtClose
FROM AllRows
ORDER BY
    CASE WHEN RowType = 'Total' THEN 0 ELSE 1 END,
    ReportDate;
