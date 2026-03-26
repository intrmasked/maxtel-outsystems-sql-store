-- =============================================
-- Query: GetRawStockTotalVariance
-- Purpose: Total Variance card for Raw Stock summary screen.
--          Returns TotalVarDollar + TotalVarPercent across all
--          filtered rows (not just current page).
--          Only rows where CloseQtyIsTheo = false on the last
--          period qualify for variance calculation.
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

-- [CTE 1]: Date boundaries per LogicalItem
Bounds AS (
    SELECT
        SB.LogicalItemId,
        MAX(SP.Date) AS LastDate
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    WHERE SP.SiteId IN (@SiteIds)
      AND SP.Date BETWEEN (SELECT StartDate FROM InputVar) AND (SELECT EndDate FROM InputVar)
    GROUP BY SB.LogicalItemId
),

-- [CTE 2]: Summed TheoConsumed across all periods (for Var % denominator)
Sums AS (
    SELECT
        SB.LogicalItemId,
        SUM(SB.TheoConsumedQty) AS TotalTheoConsumed
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    WHERE SP.SiteId IN (@SiteIds)
      AND SP.Date BETWEEN (SELECT StartDate FROM InputVar) AND (SELECT EndDate FROM InputVar)
    GROUP BY SB.LogicalItemId
),

-- [CTE 3]: Last period snapshot — only rows where CloseQtyIsTheo = false
LastPeriod AS (
    SELECT
        SB.LogicalItemId,
        SB.ActualClosedQty,
        SB.TheoClosedQty,
        SB.ItemCostAtClose
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    JOIN Bounds B ON SB.LogicalItemId = B.LogicalItemId AND SP.Date = B.LastDate
    WHERE SP.SiteId IN (@SiteIds)
      AND SB.CloseQtyIsTheo = 0
)

-- [FINAL]: Aggregate variance across all qualifying rows
SELECT
    SUM((LP.ActualClosedQty - LP.TheoClosedQty) * LP.ItemCostAtClose) AS TotalVarDollar,

    CASE
        WHEN SUM(S.TotalTheoConsumed) = 0 THEN NULL
        ELSE SUM(LP.ActualClosedQty - LP.TheoClosedQty)
             * 100.0
             / SUM(S.TotalTheoConsumed)
    END AS TotalVarPercent

FROM LastPeriod LP
JOIN Sums S ON LP.LogicalItemId = S.LogicalItemId
JOIN {LogicalItem} LI            ON LP.LogicalItemId = LI.Id
JOIN {PhysicalItem} PI           ON LI.DefaultPhysicalItemId = PI.Id
JOIN {CentralStockItem} CSI      ON LI.ConceptId = CSI.ConceptId
                                 AND LI.WrinNumber = CSI.WrinNumber

WHERE (@ProductTypes IS NULL     OR LI.ItemType IN (@ProductTypes))
  AND (@CountFrequencies IS NULL OR CSI.DefaultCountPeriodId IN (@CountFrequencies))
  AND ((SELECT ItemSearch FROM InputVar) IS NULL
       OR LI.ItemName LIKE '%' + (SELECT ItemSearch FROM InputVar) + '%')
