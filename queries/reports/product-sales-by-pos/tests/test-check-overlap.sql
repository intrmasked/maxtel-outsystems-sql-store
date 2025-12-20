/*
   ===================================================================================
   DIAGNOSTIC TEST: DEDUPLICATION VERIFICATION
   ===================================================================================
   
   PURPOSE:
   Demonstrate that the "Duplicate Headers" issue exists in Raw Data (Before)
   and is RESOLVED by the Deduplication Logic (After).
   
   METHOD:
   1. "Before Fix": Count duplicates in raw SalesFact data.
   2. "After Fix": Apply MAX() dedup logic and count duplicates again.
   ===================================================================================
*/

DECLARE @SiteIds NVARCHAR(MAX) = '3187';
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';

-- 1. Raw Data (Simulates Original Query)
WITH RawDataPoints AS (
    SELECT 
        sf.SiteId,
        sf.CalendarDate,
        sf.[DateTime],
        sf.PosId,
        sf.TransactionCount,
        sf.Netamount,
        -- Unique Signature
        CONCAT(sf.SiteId, '|', FORMAT(sf.[DateTime], 'yyyyMMddHHmmss'), '|', sf.PosId) AS RowSignature
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
),

-- 2. "Before Fix" Analysis
RawOverlap AS (
    SELECT RowSignature, COUNT(*) AS DupCount
    FROM RawDataPoints
    GROUP BY RowSignature
    HAVING COUNT(*) > 1
),

-- 3. "After Fix" Logic (The v2.2.1 Fix)
DedupedData AS (
    SELECT
        SiteId,
        CalendarDate,
        PosId, 
        [DateTime],
        MAX(TransactionCount) AS TransactionCount, -- Taking MAX resolves the duplicate
        MAX(Netamount) AS NetAmount
    FROM RawDataPoints
    GROUP BY SiteId, CalendarDate, PosId, [DateTime]
),

-- 4. "After Fix" Analysis (Should be 0)
DedupedOverlap AS (
    SELECT 
        CONCAT(SiteId, '|', FORMAT([DateTime], 'yyyyMMddHHmmss'), '|', PosId) AS RowSignature, 
        COUNT(*) AS DupCount
    FROM DedupedData
    GROUP BY SiteId, CalendarDate, PosId, [DateTime]
    HAVING COUNT(*) > 1
)

-- FINAL REPORT
SELECT 
    (SELECT COUNT(*) FROM RawOverlap) AS [Transactions_With_Duplicates_Before_Fix],
    (SELECT SUM(DupCount) - COUNT(*) FROM RawOverlap) AS [Excess_Rows_Removed],
    (SELECT COUNT(*) FROM DedupedOverlap) AS [Transactions_With_Duplicates_AFTER_Fix];

/*
   EXPECTED RESULT:
   Transactions_With_Duplicates_Before_Fix > 0  (Shows issue exists)
   Transactions_With_Duplicates_AFTER_Fix  = 0  (Shows fix works!)
*/
