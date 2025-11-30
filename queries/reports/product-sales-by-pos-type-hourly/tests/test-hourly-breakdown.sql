-- =============================================
-- Test: Hourly Breakdown Validation
-- Purpose: Verify hourly data is correct and timezone conversion works
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';

PRINT '=== TEST 1: Raw SalesFact Data by Hour (NZ Timezone) ==='
-- Shows actual hours in NZ timezone with sales data
SELECT
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS Hour_NZ,
    Pod,
    COUNT(*) AS RecordCount,
    SUM(NetAmount) AS TotalNetAmount,
    SUM(TransactionCount) AS TotalTransactionCount
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
ORDER BY Hour_NZ, Pod;

PRINT ''
PRINT '=== TEST 2: Verify All 24 Hours Exist Per Pod ==='
-- Should show 24 rows per pod (even if 0 sales)
WITH Hours AS (
    SELECT 0 AS HourStart UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
    UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11
    UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
    UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
),
AllPods AS (
    SELECT DISTINCT Pod
    FROM {SalesFact}
    WHERE SiteId = @SiteId AND CalendarDate = @Date AND DatePeriodDimensionId = 15
        AND Pod IS NOT NULL AND Pod <> ''
)
SELECT
    COUNT(DISTINCT h.HourStart) AS TotalHours_PerPod,
    p.Pod,
    COUNT(*) AS ScaffoldRowCount
FROM Hours h
CROSS JOIN AllPods p
GROUP BY p.Pod
ORDER BY p.Pod;

PRINT ''
PRINT '=== TEST 3: Hour Formatting Verification ==='
-- Verify hour strings are formatted correctly (00-01, 01-02, etc.)
WITH Hours AS (
    SELECT 0 AS HourStart UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 23
)
SELECT
    HourStart,
    REPLICATE('0', 2 - LEN(CAST(HourStart AS VARCHAR))) + CAST(HourStart AS VARCHAR) + '-' +
    REPLICATE('0', 2 - LEN(CAST((HourStart + 1) % 24 AS VARCHAR))) + CAST((HourStart + 1) % 24 AS VARCHAR) AS FormattedHour
FROM Hours
ORDER BY HourStart;

PRINT ''
PRINT '=== TEST 4: Total Day Calculation Validation ==='
-- Verify Total Day = sum of all 24 hours
WITH HourlySales AS (
    SELECT
        Pod,
        SUM(NetAmount) AS TotalNetAmount,
        SUM(TransactionCount) AS TotalTransactionCount
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
    GROUP BY Pod
)
SELECT
    'Total Day Validation' AS Test,
    Pod,
    TotalNetAmount,
    TotalTransactionCount
FROM HourlySales
ORDER BY Pod;

PRINT ''
PRINT '=== TEST 5: YoY Comparison Data Availability ==='
-- Check if prior year data exists (364 days ago)
SELECT
    'Current Year' AS Period,
    @Date AS Date,
    COUNT(DISTINCT Pod) AS PodCount,
    COUNT(*) AS RecordCount,
    SUM(NetAmount) AS TotalSales
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

UNION ALL

SELECT
    'Prior Year' AS Period,
    DATEADD(DAY, -364, @Date) AS Date,
    COUNT(DISTINCT Pod) AS PodCount,
    COUNT(*) AS RecordCount,
    SUM(NetAmount) AS TotalSales
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
    AND SaleTypeId IS NULL;

PRINT ''
PRINT '=== TEST 6: Timezone Conversion Validation ==='
-- Compare UTC vs NZ timezone hours
SELECT TOP 10
    [DateTime] AS UTC_DateTime,
    CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time') AS NZ_DateTime,
    DATEPART(HOUR, [DateTime]) AS UTC_Hour,
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS NZ_Hour,
    NetAmount,
    Pod
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND Pod IS NOT NULL AND Pod <> ''
ORDER BY [DateTime];
