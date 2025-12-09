-- =============================================
-- Test 1: Pod Totals by Hour
-- Purpose: Shows total sales per pod per hour
-- Created: 2025-12-09
-- =============================================

-- Test Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-12-08';
DECLARE @Pod VARCHAR(50) = NULL;  -- NULL = All Pods, 'CSO' = Kiosk only, 'FC' = Counter only, 'DT' = Drive-Thru only, 'Total' = Total only

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
WHERE (@Pod IS NULL OR Pod = @Pod)  -- Filter by pod if specified
ORDER BY Hour ASC, PodSequence ASC;
