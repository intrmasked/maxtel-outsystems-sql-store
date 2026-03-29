-- =============================================
-- Test: GetRawStockDetail — SSMS sandbox version
-- Purpose: Full query with DECLARE params for local testing
-- Target: SQL Server 2016+ (SSMS)
-- =============================================

DECLARE @SiteId          BIGINT = 3187;
DECLARE @StartDate       DATE = '2026-03-01';
DECLARE @EndDate         DATE = '2026-03-25';
DECLARE @LogicalItemId   BIGINT = 1;              -- Change to a valid LogicalItemId

WITH

-- [CTE 1]: Get item metadata
ItemInfo AS (
    SELECT
        LI.Id              AS LogicalItemId,
        LI.ItemName,
        LI.ItemType,
        LI.WrinNumber,
        PI.UnitName,
        PI.PortionsPerUnit,
        CSI.DefaultCountPeriodId
    FROM {LogicalItem} LI
    JOIN {PhysicalItem} PI           ON LI.DefaultPhysicalItemId = PI.Id
    JOIN {CentralStockItem} CSI      ON LI.ConceptId = CSI.ConceptId
                                     AND LI.WrinNumber = CSI.WrinNumber
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
        SB.OpenQty           / II.PortionsPerUnit   AS StartingCount,
        SB.StartIsTheo,
        CAST(SB.RawWasteQty AS DECIMAL(18,4))      / II.PortionsPerUnit   AS RawWaste,
        CAST(SB.DeliveredQty AS DECIMAL(18,4))     / II.PortionsPerUnit   AS Deliveries,
        CAST(SB.TransferQty AS DECIMAL(18,4))      / II.PortionsPerUnit   AS Transfers,
        CAST(SB.TheoConsumedQty AS DECIMAL(18,4))  / II.PortionsPerUnit   AS UnitsCPM,
        CASE
            WHEN SB.CloseQtyIsTheo = 0
            THEN SB.ActualClosedQty / II.PortionsPerUnit
            ELSE SB.TheoClosedQty   / II.PortionsPerUnit
        END AS EndCount,
        SB.CloseQtyIsTheo,
        CASE
            WHEN SB.CloseQtyIsTheo = 0
            THEN (SB.ActualClosedQty - SB.TheoClosedQty) / II.PortionsPerUnit
            ELSE NULL
        END AS VarQty,
        CASE
            WHEN SB.CloseQtyIsTheo = 0
            THEN ((SB.ActualClosedQty - SB.TheoClosedQty) / II.PortionsPerUnit)
                 * SB.ItemCostAtClose
            ELSE NULL
        END AS VarDollar,
        CASE
            WHEN SB.CloseQtyIsTheo = 0 AND SB.TheoConsumedQty <> 0
            THEN ((SB.ActualClosedQty - SB.TheoClosedQty) / SB.TheoConsumedQty) * 100
            ELSE NULL
        END AS VarPercent,
        SB.ItemCostAtClose,
        II.ItemName,
        II.ItemType,
        II.WrinNumber,
        II.UnitName,
        II.DefaultCountPeriodId
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    JOIN ItemInfo II       ON SB.LogicalItemId = II.LogicalItemId
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
        NULL             AS ItemCostAtClose,
        MAX(DD.ItemName) AS ItemName,
        MAX(DD.ItemType) AS ItemType,
        MAX(DD.WrinNumber) AS WrinNumber,
        MAX(DD.UnitName) AS UnitName,
        MAX(DD.DefaultCountPeriodId) AS DefaultCountPeriodId
    FROM DailyData DD
    CROSS JOIN FirstRow FR
    CROSS JOIN LastRow LR
    GROUP BY FR.StartingCount, FR.StartIsTheo,
             LR.EndCount, LR.CloseQtyIsTheo, LR.VarQty, LR.VarDollar

    UNION ALL

    -- Detail rows
    SELECT
        ReportDate,
        StartingCount, StartIsTheo,
        RawWaste, Deliveries, Transfers, UnitsCPM,
        EndCount, CloseQtyIsTheo,
        VarQty, VarDollar, VarPercent,
        ItemCostAtClose,
        ItemName, ItemType, WrinNumber, UnitName, DefaultCountPeriodId
    FROM DailyData
)

SELECT
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
    ItemCostAtClose,
    ItemName,
    ItemType,
    WrinNumber,
    UnitName,
    DefaultCountPeriodId
FROM AllRows
ORDER BY
    CASE WHEN ReportDate IS NULL THEN 0 ELSE 1 END,
    ReportDate;
