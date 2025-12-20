/*
   ===================================================================================
   DIAGNOSTIC TEST: PRODUCT SALES BY DAY PART - VERIFY TOTALS
   ===================================================================================
   
   Purpose: Compare parent query totals vs raw SalesFact data to find discrepancies.
   Run this in SSMS with your test parameters and compare outputs.
   
   ===================================================================================
*/

DECLARE @SiteIds NVARCHAR(MAX) = '3188';  -- Change to your test site
DECLARE @StartDate DATE = '2025-10-25';
DECLARE @EndDate DATE = '2025-11-25';
DECLARE @TestDate DATE = '2025-11-18';  -- Pick a specific date to verify

-- ============================================================================
-- TEST 1: Raw data with NZ timezone conversion for one date
-- Shows EXACTLY what's in SalesFact with the hour in NZ time
-- ============================================================================
PRINT '=== TEST 1: Raw Data with NZ Hour for Single Date ==='

SELECT 
    sf.SiteId,
    sf.CalendarDate,
    sf.[DateTime] AS UTC_DateTime,
    CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time') AS NZ_DateTime,
    DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS NZ_Hour,
    CASE
        WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 0  
         AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 5  THEN 'Overnight (00-05)'
        WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 5  
         AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 11 THEN 'Breakfast (05-11)'
        WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 11 
         AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 17 THEN 'Day (11-17)'
        WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 17 THEN 'Night (17-24)'
    END AS DayPart,
    sf.NetAmount,
    sf.TransactionCount
FROM {SalesFact} sf
WHERE sf.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
  AND sf.CalendarDate = @TestDate
  AND sf.DatePeriodDimensionId = 15
  AND sf.ProductSaleTypeId = 1
  AND sf.ProductMenuId IS NULL
  AND sf.TenderTypeId IS NULL
  AND sf.OperationId IS NULL
  AND sf.OperationKindId IS NULL
  AND sf.SWCCashDrawerId IS NULL
  AND sf.SaleTypeId IS NULL
  AND sf.Pod = ''
  AND ISNULL(sf.PosId, 0) = 0
ORDER BY sf.[DateTime];

-- ============================================================================
-- TEST 2: Totals per DayPart for test date
-- ============================================================================
PRINT '=== TEST 2: Expected Totals per DayPart for Single Date ==='

SELECT 
    CASE
        WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 0  
         AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 5  THEN 'Overnight (00-05)'
        WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 5  
         AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 11 THEN 'Breakfast (05-11)'
        WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 11 
         AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 17 THEN 'Day (11-17)'
        WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 17 THEN 'Night (17-24)'
    END AS DayPart,
    SUM(sf.NetAmount) AS TotalNetAmount,
    SUM(sf.TransactionCount) AS TotalTransactionCount,
    COUNT(*) AS RowCount
FROM {SalesFact} sf
WHERE sf.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
  AND sf.CalendarDate = @TestDate
  AND sf.DatePeriodDimensionId = 15
  AND sf.ProductSaleTypeId = 1
  AND sf.ProductMenuId IS NULL
  AND sf.TenderTypeId IS NULL
  AND sf.OperationId IS NULL
  AND sf.OperationKindId IS NULL
  AND sf.SWCCashDrawerId IS NULL
  AND sf.SaleTypeId IS NULL
  AND sf.Pod = ''
  AND ISNULL(sf.PosId, 0) = 0
GROUP BY 
    CASE
        WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 0  
         AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 5  THEN 'Overnight (00-05)'
        WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 5  
         AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 11 THEN 'Breakfast (05-11)'
        WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 11 
         AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 17 THEN 'Day (11-17)'
        WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 17 THEN 'Night (17-24)'
    END
ORDER BY DayPart;

-- ============================================================================
-- TEST 3: Grand total for test date (all day parts combined)
-- This should match the "Total (00-24)" row in your query output
-- ============================================================================
PRINT '=== TEST 3: Grand Total for Date (Should Match Total Row) ==='

SELECT 
    @TestDate AS TestDate,
    SUM(sf.NetAmount) AS GrandTotalNet,
    SUM(sf.TransactionCount) AS GrandTotalTxn
FROM {SalesFact} sf
WHERE sf.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
  AND sf.CalendarDate = @TestDate
  AND sf.DatePeriodDimensionId = 15
  AND sf.ProductSaleTypeId = 1
  AND sf.ProductMenuId IS NULL
  AND sf.TenderTypeId IS NULL
  AND sf.OperationId IS NULL
  AND sf.OperationKindId IS NULL
  AND sf.SWCCashDrawerId IS NULL
  AND sf.SaleTypeId IS NULL
  AND sf.Pod = ''
  AND ISNULL(sf.PosId, 0) = 0;

-- ============================================================================
-- TEST 4: Verify CalendarDate vs NZ Date alignment
-- Check if any transactions land on different NZ date than CalendarDate
-- ============================================================================
PRINT '=== TEST 4: CalendarDate vs NZ Date (Check for Date Shift Issues) ==='

SELECT 
    sf.CalendarDate AS SQLCalendarDate,
    CAST(CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time') AS DATE) AS NZ_Date,
    COUNT(*) AS RowCount,
    SUM(sf.NetAmount) AS NetAmount
FROM {SalesFact} sf
WHERE sf.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
  AND sf.CalendarDate BETWEEN @StartDate AND @EndDate
  AND sf.DatePeriodDimensionId = 15
  AND sf.ProductSaleTypeId = 1
  AND sf.ProductMenuId IS NULL
  AND sf.TenderTypeId IS NULL
  AND sf.OperationId IS NULL
  AND sf.OperationKindId IS NULL
  AND sf.SWCCashDrawerId IS NULL
  AND sf.SaleTypeId IS NULL
  AND sf.Pod = ''
  AND ISNULL(sf.PosId, 0) = 0
GROUP BY 
    sf.CalendarDate,
    CAST(CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time') AS DATE)
HAVING sf.CalendarDate <> CAST(CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time') AS DATE)
ORDER BY sf.CalendarDate;

-- ============================================================================
-- TEST 5: Compare CY vs PY totals for a date
-- ============================================================================
PRINT '=== TEST 5: CY vs PY Totals Comparison ==='

SELECT 'CY' AS YearType, @TestDate AS Date,
    SUM(sf.NetAmount) AS TotalNet,
    SUM(sf.TransactionCount) AS TotalTxn
FROM {SalesFact} sf
WHERE sf.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
  AND sf.CalendarDate = @TestDate
  AND sf.DatePeriodDimensionId = 15
  AND sf.ProductSaleTypeId = 1
  AND sf.ProductMenuId IS NULL
  AND sf.TenderTypeId IS NULL
  AND sf.OperationId IS NULL
  AND sf.OperationKindId IS NULL
  AND sf.SWCCashDrawerId IS NULL
  AND sf.SaleTypeId IS NULL
  AND sf.Pod = ''
  AND ISNULL(sf.PosId, 0) = 0

UNION ALL

SELECT 'PY' AS YearType, DATEADD(DAY, -364, @TestDate) AS Date,
    SUM(sf.NetAmount) AS TotalNet,
    SUM(sf.TransactionCount) AS TotalTxn
FROM {SalesFact} sf
WHERE sf.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
  AND sf.CalendarDate = DATEADD(DAY, -364, @TestDate)
  AND sf.DatePeriodDimensionId = 15
  AND sf.ProductSaleTypeId = 1
  AND sf.ProductMenuId IS NULL
  AND sf.TenderTypeId IS NULL
  AND sf.OperationId IS NULL
  AND sf.OperationKindId IS NULL
  AND sf.SWCCashDrawerId IS NULL
  AND sf.SaleTypeId IS NULL
  AND sf.Pod = ''
  AND ISNULL(sf.PosId, 0) = 0;
