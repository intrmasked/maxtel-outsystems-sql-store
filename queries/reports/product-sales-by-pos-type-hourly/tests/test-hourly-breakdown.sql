-- =============================================
-- TEST QUERY: Hourly Breakdown Diagnostic
-- Purpose: Check each hour individually to diagnose missing 23-24 data
-- Created: 2025-12-08
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';  -- Change to your test date

-- =============================================
-- PART 1: Raw Data by Hour (Before any transformation)
-- Shows EXACTLY what's in SalesFact for each UTC hour
-- =============================================

SELECT
    'RAW DATA - UTC Hours' AS TestSection,
    DATEPART(HOUR, [DateTime]) AS UTC_Hour,
    Pod,
    COUNT(*) AS RecordCount,
    SUM(NetAmount) AS TotalNetAmount,
    SUM(TransactionCount) AS TotalTransactions
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
    DATEPART(HOUR, [DateTime]),
    Pod
ORDER BY UTC_Hour, Pod;

-- =============================================
-- PART 2: After Timezone Conversion (NZ Hours)
-- Shows what hour each record falls into AFTER NZ timezone conversion
-- =============================================

SELECT
    'AFTER TIMEZONE CONVERSION - NZ Hours' AS TestSection,
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS NZ_Hour,
    Pod,
    COUNT(*) AS RecordCount,
    SUM(NetAmount) AS TotalNetAmount,
    SUM(TransactionCount) AS TotalTransactions
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
ORDER BY NZ_Hour, Pod;

-- =============================================
-- PART 3: Check for records at day boundaries
-- This checks if 23-24 hour data might be spilling into next day
-- =============================================

SELECT
    'DAY BOUNDARY CHECK' AS TestSection,
    CalendarDate,
    DATEPART(HOUR, [DateTime]) AS UTC_Hour,
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS NZ_Hour,
    CAST([DateTime] AS DATETIME) AS DateTime_UTC,
    CAST([DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time' AS DATETIME) AS DateTime_NZ,
    Pod,
    NetAmount,
    TransactionCount
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND (
        CalendarDate = @Date
        OR CalendarDate = DATEADD(DAY, -1, @Date)  -- Check previous day
        OR CalendarDate = DATEADD(DAY, 1, @Date)   -- Check next day
    )
    AND DatePeriodDimensionId = 15
    AND Pod IS NOT NULL AND Pod <> ''
    AND ProductSaleTypeId = 1
    AND ProductMenuId IS NULL
    AND TenderTypeId IS NULL
    AND OperationId IS NULL
    AND OperationKindId IS NULL
    AND SWCCashDrawerId IS NULL
    AND SaleTypeId IS NULL
    AND (
        DATEPART(HOUR, [DateTime]) >= 22  -- UTC hours 22-23
        OR DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 22  -- NZ hours 22-23
    )
ORDER BY DateTime_UTC;

-- =============================================
-- PART 4: Hour 23 Specific Check
-- Detailed check for hour 23 data specifically
-- =============================================

SELECT
    'HOUR 23 DETAIL CHECK' AS TestSection,
    CalendarDate,
    CAST([DateTime] AS DATETIME) AS DateTime_UTC,
    CAST([DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time' AS DATETIME) AS DateTime_NZ,
    DATEPART(HOUR, [DateTime]) AS UTC_Hour,
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS NZ_Hour,
    Pod,
    NetAmount,
    TransactionCount
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
    AND DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) = 23
ORDER BY DateTime_UTC;

-- =============================================
-- PART 5: Summary by Hour (What main query should produce)
-- Shows total per NZ hour across all pods
-- =============================================

SELECT
    'SUMMARY BY NZ HOUR' AS TestSection,
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS NZ_Hour,
    REPLICATE('0', 2 - LEN(CAST(DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS VARCHAR))) +
    CAST(DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS VARCHAR) + '-' +
    REPLICATE('0', 2 - LEN(CAST((DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) + 1) % 24 AS VARCHAR))) +
    CAST((DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) + 1) % 24 AS VARCHAR) AS HourLabel,
    COUNT(DISTINCT Pod) AS PodCount,
    SUM(NetAmount) AS TotalNetAmount,
    SUM(TransactionCount) AS TotalTransactions
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
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time'))
ORDER BY NZ_Hour;

-- =============================================
-- EXPECTED OUTPUT:
--
-- PART 1: Shows raw UTC data (what's physically in database)
-- PART 2: Shows data after NZ timezone conversion (what query uses)
-- PART 3: Shows boundary records (is 23-24 data spilling to next day?)
-- PART 4: Shows hour 23 records in detail
-- PART 5: Shows summary that should match main query
--
-- DEBUGGING STEPS:
-- 1. Check PART 1 - Is there data in UTC hours 10-11 or 11-12? (NZST = UTC+12, NZDT = UTC+13)
-- 2. Check PART 2 - Does NZ hour 23 show data?
-- 3. Check PART 3 - Is hour 23 data crossing day boundary?
-- 4. Check PART 4 - Are there actual records for NZ hour 23?
-- 5. Compare PART 5 totals with main query output
--
-- =============================================
