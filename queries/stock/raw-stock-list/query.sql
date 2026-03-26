-- =============================================
-- Query: GetRawStockList
-- Purpose: Raw Stock summary — one row per LogicalItem
--          with aggregated stock movements across date range.
--          Starting Count = first period, End Count = last period,
--          all other fields summed across all periods.
--          Includes a Total row (RowType = 'Total').
--
--   OUTPUT FORMAT:
--   RowType: 'Total' | 'Detail'
--
-- Target: SQL Server 2016+ / OutSystems Advanced SQL
-- Created: 2026-03-25
-- =============================================

WITH

-- [CTE 0]: InputVar — force OutSystems parameter binding (Lazy Parser fix)
InputVar AS (
    SELECT
        @StartDate  AS StartDate,
        @EndDate    AS EndDate,
        @ItemSearch AS ItemSearch
),

-- [CTE 1]: Date boundaries per LogicalItem in the selected range
Bounds AS (
    SELECT
        SB.LogicalItemId,
        MIN(SP.Date) AS FirstDate,
        MAX(SP.Date) AS LastDate
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    WHERE SP.SiteId IN (@SiteIds)
      AND SP.Date BETWEEN (SELECT StartDate FROM InputVar) AND (SELECT EndDate FROM InputVar)
    GROUP BY SB.LogicalItemId
),

-- [CTE 2]: Summed movement fields across all periods in range
Sums AS (
    SELECT
        SB.LogicalItemId,
        SUM(SB.RawWasteQty)     AS TotalRawWaste,
        SUM(SB.DeliveredQty)    AS TotalDeliveries,
        SUM(SB.TransferQty)     AS TotalTransfers,
        SUM(SB.TheoConsumedQty) AS TotalTheoConsumed
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    WHERE SP.SiteId IN (@SiteIds)
      AND SP.Date BETWEEN (SELECT StartDate FROM InputVar) AND (SELECT EndDate FROM InputVar)
    GROUP BY SB.LogicalItemId
),

-- [CTE 3]: First period snapshot — Starting Count
FirstPeriod AS (
    SELECT
        SB.LogicalItemId,
        SB.OpenQty    AS StartingCountPortions,
        SB.StartIsTheo
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    JOIN Bounds B ON SB.LogicalItemId = B.LogicalItemId AND SP.Date = B.FirstDate
    WHERE SP.SiteId IN (@SiteIds)
),

-- [CTE 4]: Last period snapshot — End Count + Variance inputs
LastPeriod AS (
    SELECT
        SB.LogicalItemId,
        SB.ActualClosedQty,
        SB.TheoClosedQty,
        SB.CloseQtyIsTheo,
        SB.ItemCostAtClose
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    JOIN Bounds B ON SB.LogicalItemId = B.LogicalItemId AND SP.Date = B.LastDate
    WHERE SP.SiteId IN (@SiteIds)
),

-- [CTE 5]: Detail rows — one per LogicalItem with all calculated fields
FilteredData AS (
    SELECT
        LI.Id                AS LogicalItemId,
        LI.ItemName,
        LI.ItemType,
        PI.UnitName,
        PI.PortionsPerUnit,
        CSI.DefaultCountPeriodId,

        -- Starting Count (first period, converted to units)
        FP.StartingCountPortions / PI.PortionsPerUnit   AS StartingCount,
        FP.StartIsTheo,

        -- Summed movement columns (converted to units)
        S.TotalRawWaste     / PI.PortionsPerUnit        AS RawWaste,
        S.TotalDeliveries   / PI.PortionsPerUnit        AS Deliveries,
        S.TotalTransfers    / PI.PortionsPerUnit        AS Transfers,
        S.TotalTheoConsumed / PI.PortionsPerUnit        AS UnitsCPM,

        -- End Count (last period, converted to units)
        CASE
            WHEN LP.CloseQtyIsTheo = 0
            THEN LP.ActualClosedQty / PI.PortionsPerUnit
            ELSE LP.TheoClosedQty   / PI.PortionsPerUnit
        END AS EndCount,
        LP.CloseQtyIsTheo,

        -- Var Qty (last period only, converted to units)
        CASE
            WHEN LP.CloseQtyIsTheo = 0
            THEN (LP.ActualClosedQty - LP.TheoClosedQty) / PI.PortionsPerUnit
            ELSE NULL
        END AS VarQty,

        -- Var $ (Var Qty * ItemCostAtClose)
        CASE
            WHEN LP.CloseQtyIsTheo = 0
            THEN ((LP.ActualClosedQty - LP.TheoClosedQty) / PI.PortionsPerUnit)
                 * LP.ItemCostAtClose
            ELSE NULL
        END AS VarDollar,

        -- Var % (Var Qty / total TheoConsumed in units * 100)
        CASE
            WHEN LP.CloseQtyIsTheo = 0 AND S.TotalTheoConsumed <> 0
            THEN ((LP.ActualClosedQty - LP.TheoClosedQty) / S.TotalTheoConsumed) * 100
            ELSE NULL
        END AS VarPercent,

        LP.ItemCostAtClose

    FROM {LogicalItem} LI
    JOIN {PhysicalItem} PI           ON LI.DefaultPhysicalItemId = PI.Id
    JOIN {CentralStockItem} CSI      ON LI.ConceptId = CSI.ConceptId
                                     AND LI.WrinNumber = CSI.WrinNumber
    JOIN Sums S                      ON LI.Id = S.LogicalItemId
    JOIN FirstPeriod FP              ON LI.Id = FP.LogicalItemId
    JOIN LastPeriod LP               ON LI.Id = LP.LogicalItemId

    WHERE (@ProductTypes IS NULL     OR LI.ItemType IN (@ProductTypes))
      AND (@CountFrequencies IS NULL OR CSI.DefaultCountPeriodId IN (@CountFrequencies))
      AND ((SELECT ItemSearch FROM InputVar) IS NULL
           OR LI.ItemName LIKE '%' + (SELECT ItemSearch FROM InputVar) + '%')
),

-- [CTE 6]: Combine Total + Detail rows
AllRows AS (
    -- Total row
    SELECT
        'Total'  AS RowType,
        0        AS LogicalItemId,
        'Total'  AS ItemName,
        ''       AS ItemType,
        ''       AS UnitName,
        0        AS PortionsPerUnit,
        0        AS DefaultCountPeriodId,
        NULL     AS StartingCount,
        CAST(0 AS BIT) AS StartIsTheo,
        SUM(RawWaste)   AS RawWaste,
        SUM(Deliveries)  AS Deliveries,
        SUM(Transfers)   AS Transfers,
        SUM(UnitsCPM)    AS UnitsCPM,
        NULL     AS EndCount,
        CAST(0 AS BIT) AS CloseQtyIsTheo,
        SUM(VarQty)      AS VarQty,
        SUM(VarDollar)   AS VarDollar,
        CASE
            WHEN SUM(UnitsCPM) = 0 THEN NULL
            ELSE SUM(VarQty) / SUM(UnitsCPM) * 100
        END AS VarPercent,
        NULL     AS ItemCostAtClose
    FROM FilteredData

    UNION ALL

    -- Detail rows
    SELECT
        'Detail',
        LogicalItemId, ItemName, ItemType, UnitName, PortionsPerUnit,
        DefaultCountPeriodId,
        StartingCount, StartIsTheo,
        RawWaste, Deliveries, Transfers, UnitsCPM,
        EndCount, CloseQtyIsTheo,
        VarQty, VarDollar, VarPercent,
        ItemCostAtClose
    FROM FilteredData
)

-- [FINAL]: Output
SELECT
    RowType,
    LogicalItemId,
    ItemName,
    ItemType,
    UnitName,
    PortionsPerUnit,
    DefaultCountPeriodId,
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
    ItemName
