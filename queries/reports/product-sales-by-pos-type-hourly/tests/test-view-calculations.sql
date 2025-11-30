-- =============================================
-- Test: View Calculations Validation (D, G, A)
-- Purpose: Verify Sales, Guest Count, and Average Check calculations are correct
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';

PRINT '=== TEST 1: Dollar Sales View (D) - Verify NetAmount ==='
-- Should show NetAmount for each hour-pod combination
SELECT
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS Hour,
    Pod,
    SUM(NetAmount) AS Sales_D,
    COUNT(*) AS RecordCount
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND Pod IS NOT NULL
    AND Pod <> ''
    AND ProductSaleTypeId = 1
    AND ProductMenuId IS NULL
    AND TenderTypeId IS NULL
    AND OperationId IS NULL
    AND OperationKindId IS NULL
    AND SWCCashDrawerId IS NULL
    AND SaleTypeId IS NULL
GROUP BY
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')),
    Pod
HAVING SUM(NetAmount) > 0
ORDER BY Hour, Pod;

PRINT ''
PRINT '=== TEST 2: Guest Count View (G) - Verify TransactionCount ==='
-- Should show TransactionCount for each hour-pod combination
SELECT
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS Hour,
    Pod,
    SUM(TransactionCount) AS Sales_G,
    COUNT(*) AS RecordCount
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND Pod IS NOT NULL
    AND Pod <> ''
    AND ProductSaleTypeId = 1
    AND ProductMenuId IS NULL
    AND TenderTypeId IS NULL
    AND OperationId IS NULL
    AND OperationKindId IS NULL
    AND SWCCashDrawerId IS NULL
    AND SaleTypeId IS NULL
GROUP BY
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')),
    Pod
HAVING SUM(TransactionCount) > 0
ORDER BY Hour, Pod;

PRINT ''
PRINT '=== TEST 3: Average Check View (A) - Verify NetAmount/TransactionCount ==='
-- Should show NetAmount / TransactionCount for each hour-pod combination
SELECT
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS Hour,
    Pod,
    SUM(NetAmount) AS TotalNetAmount,
    SUM(TransactionCount) AS TotalTransactionCount,
    CASE
        WHEN SUM(TransactionCount) = 0 THEN 0
        ELSE SUM(NetAmount) / SUM(TransactionCount)
    END AS Sales_A_AvgCheck
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND Pod IS NOT NULL
    AND Pod <> ''
    AND ProductSaleTypeId = 1
    AND ProductMenuId IS NULL
    AND TenderTypeId IS NULL
    AND OperationId IS NULL
    AND OperationKindId IS NULL
    AND SWCCashDrawerId IS NULL
    AND SaleTypeId IS NULL
GROUP BY
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')),
    Pod
HAVING SUM(NetAmount) > 0
ORDER BY Hour, Pod;

PRINT ''
PRINT '=== TEST 4: PercentTotal Calculation - Dollar Sales ==='
-- Verify each pod's % of hour total adds up to ~100%
WITH HourlyData AS (
    SELECT
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS Hour,
        Pod,
        SUM(NetAmount) AS PodSales
    FROM {SalesFact}
    WHERE SiteId = @SiteId
        AND CalendarDate = @Date
        AND DatePeriodDimensionId = 15
        AND Pod IS NOT NULL
        AND Pod <> ''
        AND ProductSaleTypeId = 1
        AND ProductMenuId IS NULL
        AND TenderTypeId IS NULL
        AND OperationId IS NULL
        AND OperationKindId IS NULL
        AND SWCCashDrawerId IS NULL
        AND SaleTypeId IS NULL
    GROUP BY
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')),
        Pod
),
HourTotals AS (
    SELECT
        Hour,
        SUM(PodSales) AS HourTotal
    FROM HourlyData
    GROUP BY Hour
)
SELECT
    hd.Hour,
    hd.Pod,
    hd.PodSales,
    ht.HourTotal,
    (hd.PodSales * 100.0 / NULLIF(ht.HourTotal, 0)) AS PercentTotal
FROM HourlyData hd
INNER JOIN HourTotals ht ON hd.Hour = ht.Hour
WHERE hd.PodSales > 0
ORDER BY hd.Hour, hd.Pod;

PRINT ''
PRINT '=== TEST 5: Verify PercentTotal Sums to 100% Per Hour ==='
-- Each hour should sum to ~100% across all pods
WITH HourlyData AS (
    SELECT
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS Hour,
        Pod,
        SUM(NetAmount) AS PodSales
    FROM {SalesFact}
    WHERE SiteId = @SiteId
        AND CalendarDate = @Date
        AND DatePeriodDimensionId = 15
        AND Pod IS NOT NULL
        AND Pod <> ''
        AND ProductSaleTypeId = 1
        AND ProductMenuId IS NULL
        AND TenderTypeId IS NULL
        AND OperationId IS NULL
        AND OperationKindId IS NULL
        AND SWCCashDrawerId IS NULL
        AND SaleTypeId IS NULL
    GROUP BY
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')),
        Pod
),
HourTotals AS (
    SELECT
        Hour,
        SUM(PodSales) AS HourTotal
    FROM HourlyData
    GROUP BY Hour
)
SELECT
    hd.Hour,
    SUM(hd.PodSales * 100.0 / NULLIF(ht.HourTotal, 0)) AS TotalPercent_ShouldBe100
FROM HourlyData hd
INNER JOIN HourTotals ht ON hd.Hour = ht.Hour
GROUP BY hd.Hour
HAVING SUM(hd.PodSales) > 0
ORDER BY hd.Hour;

PRINT ''
PRINT '=== TEST 6: YoY PercentInc Calculation ==='
-- Verify YoY growth % calculation
WITH CY AS (
    SELECT
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS Hour,
        Pod,
        SUM(NetAmount) AS CY_Sales
    FROM {SalesFact}
    WHERE SiteId = @SiteId
        AND CalendarDate = @Date
        AND DatePeriodDimensionId = 15
        AND Pod IS NOT NULL AND Pod <> ''
        AND ProductSaleTypeId = 1
        AND ProductMenuId IS NULL
        AND TenderTypeId IS NULL
        AND OperationId IS NULL
        AND OperationKindId IS NULL
        AND SWCCashDrawerId IS NULL
        AND SaleTypeId IS NULL
    GROUP BY
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')),
        Pod
),
PY AS (
    SELECT
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS Hour,
        Pod,
        SUM(NetAmount) AS PY_Sales
    FROM {SalesFact}
    WHERE SiteId = @SiteId
        AND CalendarDate = DATEADD(DAY, -364, @Date)
        AND DatePeriodDimensionId = 15
        AND Pod IS NOT NULL AND Pod <> ''
        AND ProductSaleTypeId = 1
        AND ProductMenuId IS NULL
        AND TenderTypeId IS NULL
        AND OperationId IS NULL
        AND OperationKindId IS NULL
        AND SWCCashDrawerId IS NULL
        AND SaleTypeId IS NULL
    GROUP BY
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')),
        Pod
)
SELECT
    cy.Hour,
    cy.Pod,
    cy.CY_Sales,
    ISNULL(py.PY_Sales, 0) AS PY_Sales,
    CASE
        WHEN ISNULL(py.PY_Sales, 0) = 0 THEN 0
        ELSE (cy.CY_Sales - py.PY_Sales) * 100.0 / py.PY_Sales
    END AS PercentInc
FROM CY cy
LEFT JOIN PY py ON cy.Hour = py.Hour AND cy.Pod = py.Pod
WHERE cy.CY_Sales > 0
ORDER BY cy.Hour, cy.Pod;
