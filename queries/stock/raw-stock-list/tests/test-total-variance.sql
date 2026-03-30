-- =============================================
-- Test: GetRawStockTotalVariance — SSMS sandbox version
-- Purpose: Total Variance card query with DECLARE params
-- =============================================

DECLARE @SiteIds       VARCHAR(100) = '3187';
DECLARE @StartDate     DATE = '2026-03-28';
DECLARE @EndDate       DATE = '2026-03-29';
DECLARE @ItemSearch    VARCHAR(100) = NULL;
DECLARE @ProductTypes  VARCHAR(100) = NULL;
DECLARE @CountFreqs    VARCHAR(100) = NULL;

WITH

-- Date boundaries (only need LastDate for variance)
Bounds AS (
    SELECT
        SB.LogicalItemId,
        MAX(SP.Date) AS LastDate
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    WHERE SP.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
      AND SP.Date BETWEEN @StartDate AND @EndDate
    GROUP BY SB.LogicalItemId
),

-- Summed TheoConsumed (for Var % denominator)
Sums AS (
    SELECT
        SB.LogicalItemId,
        SUM(SB.TheoConsumedQty) AS TotalTheoConsumed
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    WHERE SP.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
      AND SP.Date BETWEEN @StartDate AND @EndDate
    GROUP BY SB.LogicalItemId
),

-- Last period — only rows with actual count (CloseQtyIsTheo = false)
LastPeriod AS (
    SELECT
        SB.LogicalItemId,
        SB.ActualClosedQty,
        SB.TheoClosedQty,
        SB.ItemCostAtClose
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    JOIN Bounds B ON SB.LogicalItemId = B.LogicalItemId AND SP.Date = B.LastDate
    WHERE SP.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
      AND SB.CloseQtyIsTheo = 0
)

SELECT
    SUM((LP.ActualClosedQty - LP.TheoClosedQty) * LP.ItemCostAtClose) AS TotalVarDollar,

    CASE
        WHEN SUM(S.TotalTheoConsumed) = 0 THEN NULL
        ELSE SUM(LP.ActualClosedQty - LP.TheoClosedQty)
             * 100.0
             / SUM(S.TotalTheoConsumed)
    END AS TotalVarPercent

FROM LastPeriod LP
JOIN Sums S                       ON LP.LogicalItemId = S.LogicalItemId
JOIN {LogicalItem} LI       ON LP.LogicalItemId = LI.Id
JOIN {PhysicalItem} PI      ON LI.DefaultPhysicalItemId = PI.Id
LEFT JOIN {CentralStockItem} CSI ON LI.ConceptId = CSI.ConceptId
                                 AND LI.WrinNumber = CSI.WrinNumberClean

WHERE (@ProductTypes IS NULL
       OR LI.ItemType IN (SELECT LTRIM(value) FROM STRING_SPLIT(@ProductTypes, ',')))
  AND (@CountFreqs IS NULL
       OR CSI.DefaultCountPeriodId IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@CountFreqs, ','))
       OR CSI.DefaultCountPeriodId IS NULL)
  AND (@ItemSearch IS NULL
       OR LI.ItemName LIKE '%' + @ItemSearch + '%');
