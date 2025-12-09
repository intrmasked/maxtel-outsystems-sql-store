-- =============================================
-- Test: Product Sales By POS Type Hourly - Pod Totals Verification
-- Purpose: Verify pod totals match expected values
-- Created: 2025-12-09
-- =============================================

-- Test Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-12-08';

-- =============================================
-- TEST 1: Pod Totals by Hour
-- Shows total sales per pod per hour
-- =============================================

WITH

Hours AS (
    SELECT 0 AS HourStart
    UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14
    UNION ALL SELECT 15 UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
),

RawData AS (
    SELECT
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS HourStart,
        Pod,
        SUM(NetAmount) AS NetAmount,
        SUM(TransactionCount) AS TransactionCount
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

ActivePods AS (
    SELECT DISTINCT Pod
    FROM RawData
),

Scaffold AS (
    SELECT
        h.HourStart,
        REPLICATE('0', 2 - LEN(CAST(h.HourStart AS VARCHAR))) + CAST(h.HourStart AS VARCHAR) + '-' +
        REPLICATE('0', 2 - LEN(CAST((h.HourStart + 1) AS VARCHAR))) + CAST((h.HourStart + 1) AS VARCHAR) AS Hour,
        p.Pod
    FROM Hours h
    CROSS JOIN ActivePods p
),

MergedData AS (
    SELECT
        s.Hour,
        s.Pod,
        ISNULL(rd.NetAmount, 0) AS NetAmount,
        ISNULL(rd.TransactionCount, 0) AS TransactionCount
    FROM Scaffold s
    LEFT JOIN RawData rd ON s.HourStart = rd.HourStart AND s.Pod = rd.Pod
),

TotalData AS (
    SELECT
        Hour,
        'Total' AS Pod,
        SUM(NetAmount) AS NetAmount,
        SUM(TransactionCount) AS TransactionCount
    FROM MergedData
    GROUP BY Hour
)

-- Output with verification columns
SELECT
    Hour,
    Pod,
    NetAmount AS Sales,
    TransactionCount AS GuestCount,
    CASE WHEN TransactionCount = 0 THEN 0 ELSE NetAmount / TransactionCount END AS AvgCheck,
    ROW_NUMBER() OVER (PARTITION BY Hour ORDER BY
        CASE Pod
            WHEN 'Total' THEN 0
            ELSE 1
        END,
        Pod
    ) AS PodSequence
FROM (
    SELECT * FROM MergedData
    UNION ALL
    SELECT * FROM TotalData
) Combined
ORDER BY Hour ASC, PodSequence ASC;

-- =============================================
-- TEST 2: Grand Total by Pod (Across All Hours)
-- Shows cumulative totals per pod for the day
-- =============================================

PRINT '';
PRINT '--- Grand Total by Pod (All Hours) ---';
PRINT '';

SELECT
    Pod,
    SUM(NetAmount) AS TotalSales,
    SUM(TransactionCount) AS TotalGuestCount,
    CASE WHEN SUM(TransactionCount) = 0 THEN 0
         ELSE SUM(NetAmount) / SUM(TransactionCount) END AS AvgCheck
FROM {SalesFact}
WHERE SiteId = @SiteId
  AND CalendarDate = @Date
  AND DatePeriodDimensionId = 15
  AND ProductSaleTypeId = 1
  AND ProductMenuId IS NULL
  AND TenderTypeId IS NULL
  AND OperationId IS NULL
  AND OperationKindId IS NULL
  AND SWCCashDrawerId IS NULL
  AND SaleTypeId IS NULL
  AND Pod IS NOT NULL AND Pod <> ''
GROUP BY Pod
ORDER BY Pod;

-- =============================================
-- TEST 3: Verification - Check if Totals Match Sum of Pods
-- =============================================

PRINT '';
PRINT '--- Verification: Total Row = Sum of Pod Rows per Hour ---';
PRINT '';

WITH

Hours AS (
    SELECT 0 AS HourStart
    UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14
    UNION ALL SELECT 15 UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
),

RawData AS (
    SELECT
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS HourStart,
        Pod,
        SUM(NetAmount) AS NetAmount,
        SUM(TransactionCount) AS TransactionCount
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

ActivePods AS (
    SELECT DISTINCT Pod
    FROM RawData
),

Scaffold AS (
    SELECT
        h.HourStart,
        REPLICATE('0', 2 - LEN(CAST(h.HourStart AS VARCHAR))) + CAST(h.HourStart AS VARCHAR) + '-' +
        REPLICATE('0', 2 - LEN(CAST((h.HourStart + 1) AS VARCHAR))) + CAST((h.HourStart + 1) AS VARCHAR) AS Hour,
        p.Pod
    FROM Hours h
    CROSS JOIN ActivePods p
),

MergedData AS (
    SELECT
        s.HourStart,
        s.Hour,
        s.Pod,
        ISNULL(rd.NetAmount, 0) AS NetAmount,
        ISNULL(rd.TransactionCount, 0) AS TransactionCount
    FROM Scaffold s
    LEFT JOIN RawData rd ON s.HourStart = rd.HourStart AND s.Pod = rd.Pod
),

PodSums AS (
    SELECT
        Hour,
        SUM(NetAmount) AS PodSumSales,
        SUM(TransactionCount) AS PodSumGuestCount
    FROM MergedData
    GROUP BY Hour
),

TotalRow AS (
    SELECT
        Hour,
        SUM(NetAmount) AS TotalSales,
        SUM(TransactionCount) AS TotalGuestCount
    FROM MergedData
    GROUP BY Hour
)

SELECT
    ps.Hour,
    ps.PodSumSales AS [Sum of Pods Sales],
    tr.TotalSales AS [Total Row Sales],
    CASE WHEN ABS(ps.PodSumSales - tr.TotalSales) < 0.01 THEN 'PASS' ELSE 'FAIL' END AS [Sales Match],
    ps.PodSumGuestCount AS [Sum of Pods GC],
    tr.TotalGuestCount AS [Total Row GC],
    CASE WHEN ps.PodSumGuestCount = tr.TotalGuestCount THEN 'PASS' ELSE 'FAIL' END AS [GC Match]
FROM PodSums ps
JOIN TotalRow tr ON ps.Hour = tr.Hour
ORDER BY ps.Hour;

-- =============================================
-- TEST 4: Compare Daily Total with product-sales-by-pos Query
-- =============================================

PRINT '';
PRINT '--- Daily Total (Should match product-sales-by-pos for same date) ---';
PRINT '';

SELECT
    @Date AS Date,
    SUM(NetAmount) AS TotalSales,
    SUM(TransactionCount) AS TotalGuestCount,
    CASE WHEN SUM(TransactionCount) = 0 THEN 0
         ELSE SUM(NetAmount) / SUM(TransactionCount) END AS AvgCheck
FROM {SalesFact}
WHERE SiteId = @SiteId
  AND CalendarDate = @Date
  AND DatePeriodDimensionId = 15
  AND ProductSaleTypeId = 1
  AND ProductMenuId IS NULL
  AND TenderTypeId IS NULL
  AND OperationId IS NULL
  AND OperationKindId IS NULL
  AND SWCCashDrawerId IS NULL
  AND SaleTypeId IS NULL
  AND PosId IS NOT NULL
  AND Pod IN ('FC', 'DT', 'CSO')
  AND Pod IS NOT NULL AND Pod <> '';
