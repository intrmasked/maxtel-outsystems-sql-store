-- =============================================
-- Test: ActualSales v3 — SSMS Sandbox Version
-- Purpose: Full query with DECLARE params for SSMS testing
-- Note: Uses STRING_SPLIT for @PodList (SSMS equivalent of Expand Inline)
-- Updated: 2026-03-15 — v3: pre-resolve lookups, eliminate JOINs from SalesFact
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @BusDate DATE = '2026-03-14';
DECLARE @PodList VARCHAR(100) = 'CO,DT';
DECLARE @BrandType VARCHAR(50) = 'MCD';

WITH

-- ──────────────────────────────────────────────
-- PRE-RESOLVE: Tiny lookups BEFORE touching SalesFact
-- ──────────────────────────────────────────────

-- [STEP 1a]: Get SWCPeriod Id (1 row)
PeriodId AS (
    SELECT Id AS PeriodId
    FROM {SWCPeriod}
    WHERE SiteId = @SiteId
      AND BusDate = @BusDate
),

-- [STEP 1b]: Get ProductMenuIds that match BrandType (small set)
BrandMenuIds AS (
    SELECT P.Id AS ProductMenuId
    FROM {ProductMenu} P
    INNER JOIN {BO_MenuItem} B
        ON P.ProductId = B.[MIN]
        AND P.ConceptId = B.ConceptId
    WHERE B.BrandType = @BrandType
),

-- [STEP 1c]: Pre-fetch SalesHour projections (max ~24 rows)
Projections AS (
    SELECT
        DATEPART(HOUR, sh.StartDateTime) AS ProjHour,
        CAST(sh.StartDateTime AS DATE) AS ProjDate,
        sh.ProjectedSalesExclGST
    FROM {SalesHour} sh
    WHERE sh.SiteId = @SiteId
      AND CAST(sh.StartDateTime AS DATE) IN (@BusDate, DATEADD(DAY, 1, @BusDate))
),

-- ──────────────────────────────────────────────
-- SALESFACT: One scan, ZERO JOINs
-- ──────────────────────────────────────────────

-- [STEP 2]: Actual Sales — direct scan with pre-resolved filters
ActualSales AS (
    SELECT
        S.[POD],
        DATEADD(MINUTE, 15, S.[DateTime]) AS QtrHr,
        DATEPART(HOUR, S.[DateTime]) AS SalesHour,
        CAST(S.[DateTime] AS DATE) AS SalesDate,
        SUM(S.NetAmount) AS ProductSales
    FROM {SalesFact} S
    WHERE S.SWCPeriodId = (SELECT PeriodId FROM PeriodId)
      AND ISNULL(S.[PosId], '') = ''
      AND S.[POD] IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@PodList, ','))
      AND S.ProductMenuId IN (SELECT ProductMenuId FROM BrandMenuIds)
      AND ISNULL(S.SalesFactTypeId, 0) = 2
      AND S.DatePeriodDimensionId = 15
      AND ISNULL(S.OperationKindId, 0) = 0
      AND ISNULL(S.SaleTypeId, 0) = 0
    GROUP BY
        S.[POD],
        DATEADD(MINUTE, 15, S.[DateTime]),
        DATEPART(HOUR, S.[DateTime]),
        CAST(S.[DateTime] AS DATE)
),

-- [STEP 3]: Add HourlyProductSales via window function
SalesWithHourly AS (
    SELECT
        [POD],
        QtrHr,
        SalesHour,
        SalesDate,
        ProductSales,
        SUM(ProductSales) OVER (PARTITION BY SalesHour, SalesDate) AS HourlyProductSales
    FROM ActualSales
),

-- ──────────────────────────────────────────────
-- SCAFFOLD: Static 96-slot generator (no recursion)
-- ──────────────────────────────────────────────

Nums AS (
    SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
),
Hours AS (
    SELECT (t.n * 4 + u.n) AS h
    FROM (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5) t
    CROSS JOIN Nums u
    WHERE (t.n * 4 + u.n) < 24
),
SlotNums AS (
    SELECT h.h * 4 + q.n AS SlotIdx
    FROM Hours h
    CROSS JOIN Nums q
),
QtrSlots AS (
    SELECT
        DATEADD(MINUTE, (SlotIdx + 1) * 15,
            CAST(@BusDate AS DATETIME) + CAST('04:00' AS DATETIME)
        ) AS QtrHr,
        DATEPART(HOUR,
            DATEADD(MINUTE, SlotIdx * 15,
                CAST(@BusDate AS DATETIME) + CAST('04:00' AS DATETIME)
            )
        ) AS SlotHour,
        CAST(
            DATEADD(MINUTE, SlotIdx * 15,
                CAST(@BusDate AS DATETIME) + CAST('04:00' AS DATETIME)
            )
        AS DATE) AS SlotDate
    FROM SlotNums
),

-- [STEP 5]: Active Pods from actual data
ActivePods AS (
    SELECT DISTINCT [POD] AS Pod FROM ActualSales
),

-- [STEP 6]: Full Scaffold
Scaffold AS (
    SELECT q.QtrHr, q.SlotHour, q.SlotDate, p.Pod
    FROM QtrSlots q
    CROSS JOIN ActivePods p
)

-- ──────────────────────────────────────────────
-- FINAL OUTPUT
-- ──────────────────────────────────────────────

SELECT
    sc.Pod,
    sc.QtrHr,
    CAST(ISNULL(sw.ProductSales, 0) AS DECIMAL(18,2)) AS ProductSales,
    CAST(
        ROUND(
            CASE
                WHEN ISNULL(sw.HourlyProductSales, 0) = 0 THEN 0
                ELSE (ISNULL(pr.ProjectedSalesExclGST, 0) / sw.HourlyProductSales) * sw.ProductSales
            END,
            2
        )
    AS DECIMAL(18,2)) AS ProjectedProductSales
FROM Scaffold sc
LEFT JOIN SalesWithHourly sw
    ON sc.Pod = sw.[POD]
    AND sc.QtrHr = sw.QtrHr
LEFT JOIN Projections pr
    ON pr.ProjHour = sc.SlotHour
    AND pr.ProjDate = sc.SlotDate
ORDER BY sc.Pod, sc.QtrHr;
