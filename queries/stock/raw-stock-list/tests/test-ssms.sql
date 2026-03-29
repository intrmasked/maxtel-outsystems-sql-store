-- =============================================
-- Test: GetRawStockList — SSMS sandbox version
-- Purpose: Full query with DECLARE params for local testing
-- Uses STRING_SPLIT for comma-separated lists (SSMS substitute for Expand Inline)
-- Target: SQL Server 2016+ (SSMS)
-- =============================================

DECLARE @SiteIds       VARCHAR(100) = '3187';
DECLARE @StartDate     DATE = '2026-03-28';
DECLARE @EndDate       DATE = '2026-03-29';
DECLARE @ItemSearch    VARCHAR(100) = NULL;        -- NULL = no filter
DECLARE @ProductTypes  VARCHAR(100) = NULL;        -- NULL = all. e.g. 'Food,Paper'
DECLARE @CountFreqs    VARCHAR(100) = NULL;        -- NULL = all. e.g. '1,2,3'

WITH

-- Resolve site info
SiteList AS (
    SELECT S.Id AS SiteId, ISNULL(S.DisplayName, S.Name) AS SiteName
    FROM {Site} S
    WHERE S.Id IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
),

-- Date boundaries per LogicalItem
Bounds AS (
    SELECT
        SB.LogicalItemId,
        MIN(SP.Date) AS FirstDate,
        MAX(SP.Date) AS LastDate
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    WHERE SP.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
      AND SP.Date BETWEEN @StartDate AND @EndDate
    GROUP BY SB.LogicalItemId
),

-- Summed movement fields across all periods
Sums AS (
    SELECT
        SB.LogicalItemId,
        SUM(CAST(SB.RawWasteQty AS DECIMAL(18,4)))     AS TotalRawWaste,
        SUM(CAST(SB.DeliveredQty AS DECIMAL(18,4)))    AS TotalDeliveries,
        SUM(CAST(SB.TransferQty AS DECIMAL(18,4)))     AS TotalTransfers,
        SUM(CAST(SB.TheoConsumedQty AS DECIMAL(18,4))) AS TotalTheoConsumed
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    WHERE SP.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
      AND SP.Date BETWEEN @StartDate AND @EndDate
    GROUP BY SB.LogicalItemId
),

-- First period snapshot (Starting Count)
FirstPeriod AS (
    SELECT
        SB.LogicalItemId,
        SB.OpenQty    AS StartingCountPortions,
        SB.StartIsTheo
    FROM {StockPeriodBalance} SB
    JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
    JOIN Bounds B ON SB.LogicalItemId = B.LogicalItemId AND SP.Date = B.FirstDate
    WHERE SP.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
),

-- Last period snapshot (End Count + Variance)
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
    WHERE SP.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
),

-- Detail rows
FilteredData AS (
    SELECT
        LI.Id                AS LogicalItemId,
        LI.ItemName,
        LI.ItemType,
        PI.UnitName,
        PI.PortionsPerUnit,
        CSI.DefaultCountPeriodId,
        FP.StartingCountPortions / PI.PortionsPerUnit   AS StartingCount,
        FP.StartIsTheo,
        S.TotalRawWaste     / PI.PortionsPerUnit        AS RawWaste,
        S.TotalDeliveries   / PI.PortionsPerUnit        AS Deliveries,
        S.TotalTransfers    / PI.PortionsPerUnit        AS Transfers,
        S.TotalTheoConsumed / PI.PortionsPerUnit        AS UnitsCPM,
        CASE
            WHEN LP.CloseQtyIsTheo = 0
            THEN LP.ActualClosedQty / PI.PortionsPerUnit
            ELSE LP.TheoClosedQty   / PI.PortionsPerUnit
        END AS EndCount,
        LP.CloseQtyIsTheo,
        CASE
            WHEN LP.CloseQtyIsTheo = 0
            THEN (LP.ActualClosedQty - LP.TheoClosedQty) / PI.PortionsPerUnit
            ELSE NULL
        END AS VarQty,
        CASE
            WHEN LP.CloseQtyIsTheo = 0
            THEN ((LP.ActualClosedQty - LP.TheoClosedQty) / PI.PortionsPerUnit)
                 * LP.ItemCostAtClose
            ELSE NULL
        END AS VarDollar,
        CASE
            WHEN LP.CloseQtyIsTheo = 0 AND S.TotalTheoConsumed <> 0
            THEN ((LP.ActualClosedQty - LP.TheoClosedQty) / S.TotalTheoConsumed) * 100
            ELSE NULL
        END AS VarPercent,
        LP.ItemCostAtClose,
        (SELECT MIN(SiteId) FROM SiteList) AS SiteId,
        (SELECT MIN(SiteName) FROM SiteList) AS SiteName
    FROM {LogicalItem} LI
    JOIN {PhysicalItem} PI      ON LI.DefaultPhysicalItemId = PI.Id
    LEFT JOIN {CentralStockItem} CSI ON LI.ConceptId = CSI.ConceptId
                                     AND LI.WrinNumber = CSI.WrinNumberClean
    JOIN Sums S                       ON LI.Id = S.LogicalItemId
    JOIN FirstPeriod FP               ON LI.Id = FP.LogicalItemId
    JOIN LastPeriod LP                ON LI.Id = LP.LogicalItemId
    WHERE (@ProductTypes IS NULL
           OR LI.ItemType IN (SELECT LTRIM(value) FROM STRING_SPLIT(@ProductTypes, ',')))
      AND (@CountFreqs IS NULL
           OR CSI.DefaultCountPeriodId IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(@CountFreqs, ',')))
      AND (@ItemSearch IS NULL
           OR LI.ItemName LIKE '%' + @ItemSearch + '%')
),

-- Combine Total + Detail rows
AllRows AS (
    -- Total row
    SELECT
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
        NULL     AS ItemCostAtClose,
        0        AS SiteId,
        ''       AS SiteName
    FROM FilteredData

    UNION ALL

    -- Detail rows
    SELECT
        LogicalItemId, ItemName, ItemType, UnitName, PortionsPerUnit,
        DefaultCountPeriodId,
        StartingCount, StartIsTheo,
        RawWaste, Deliveries, Transfers, UnitsCPM,
        EndCount, CloseQtyIsTheo,
        VarQty, VarDollar, VarPercent,
        ItemCostAtClose,
        SiteId, SiteName
    FROM FilteredData
)

SELECT
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
    ItemCostAtClose,
    SiteId,
    SiteName
FROM AllRows
ORDER BY
    CASE WHEN ItemName = 'Total' THEN 0 ELSE 1 END,
    ItemName;
