/*
   ===================================================================================
   DIAGNOSTIC TEST: PRODUCT SALES BY POS - VERIFY TOTALS
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
-- TEST 1: Raw data for one specific date (no aggregation)
-- This shows EXACTLY what's in SalesFact for your test date
-- ============================================================================
PRINT '=== TEST 1: Raw SalesFact Data for Single Date ==='

SELECT 
    sf.SiteId,
    sf.CalendarDate,
    sf.Pod,
    sf.NetAmount,
    sf.TransactionCount,
    sf.DatePeriodDimensionId,
    sf.ProductSaleTypeId
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
  AND sf.PosId IS NOT NULL
  AND sf.Pod IS NOT NULL AND sf.Pod <> ''
ORDER BY sf.Pod;

-- ============================================================================
-- TEST 2: Raw totals per Pod for test date (what Total should equal)
-- ============================================================================
PRINT '=== TEST 2: Expected Totals per Pod for Single Date ==='

SELECT 
    sf.Pod,
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
  AND sf.PosId IS NOT NULL
  AND sf.Pod IS NOT NULL AND sf.Pod <> ''
GROUP BY sf.Pod
ORDER BY sf.Pod;

-- ============================================================================
-- TEST 3: Grand total for test date (all pods combined)
-- This should match the "Total" row in your query output
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
  AND sf.PosId IS NOT NULL
  AND sf.Pod IS NOT NULL AND sf.Pod <> '';

-- ============================================================================
-- TEST 4: Previous Year data for same date (364 days earlier)
-- ============================================================================
PRINT '=== TEST 4: Previous Year Data (364 Days Earlier) ==='

SELECT 
    DATEADD(DAY, -364, @TestDate) AS PY_Date,
    sf.Pod,
    SUM(sf.NetAmount) AS PY_TotalNet,
    SUM(sf.TransactionCount) AS PY_TotalTxn
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
  AND sf.PosId IS NOT NULL
  AND sf.Pod IS NOT NULL AND sf.Pod <> ''
GROUP BY sf.Pod
ORDER BY sf.Pod;

-- ============================================================================
-- TEST 5: Full date range totals by Pod (for the entire date range)
-- ============================================================================
PRINT '=== TEST 5: Full Date Range Totals per Pod ==='

SELECT 
    sf.Pod,
    SUM(sf.NetAmount) AS DateRangeTotalNet,
    SUM(sf.TransactionCount) AS DateRangeTotalTxn,
    COUNT(DISTINCT sf.CalendarDate) AS DaysWithData
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
  AND sf.PosId IS NOT NULL
  AND sf.Pod IS NOT NULL AND sf.Pod <> ''
GROUP BY sf.Pod
ORDER BY sf.Pod;
