/*
   ===================================================================================
   DIAGNOSTIC TEST: CHECK FOR DUPLICATES IN DAY PART (SUMMARY ROWS)
   ===================================================================================

   PURPOSE:
   Determine if the "Summary Rows" (PosId=0, Pod='') in SalesFact 
   have duplicate/overlapping headers similar to the Detailed rows.

   METHOD:
   1. Select raw rows matching the Day Part Query filters (PosId=0, Pod='').
   2. Group by Unique ID (SiteId + DateTime).
   3. Check if any ID appears > 1 time.
   ===================================================================================
*/

DECLARE @SiteIds NVARCHAR(MAX) = '3187';
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';

-- 1. Fetch Raw Data (Simulates Day Part Query Filters)
WITH RawDataPoints AS (
    SELECT 
        sf.SiteId,
        sf.CalendarDate,
        sf.[DateTime],
        sf.PosId,
        sf.Pod,
        sf.TransactionCount,
        sf.Netamount,
        -- Unique Signature for Summary Rows (Should be Site + DateTime)
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
      
      -- DAY PART SPECIFIC FILTERS
      AND sf.Pod = ''
      AND ISNULL(sf.PosId, 0) = 0
),

-- 2. Check for Duplicates
OverlapCheck AS (
    SELECT 
        RowSignature,
        COUNT(*) AS DuplicateCount,
        MIN(CalendarDate) AS SampleDate,
        MIN(SiteId) AS SiteId
    FROM RawDataPoints
    GROUP BY RowSignature
    HAVING COUNT(*) > 1
)

SELECT 
    (SELECT COUNT(*) FROM RawDataPoints) AS Total_Summary_Rows,
    (SELECT COUNT(*) FROM OverlapCheck) AS Duplicate_Signatures_Found,
    (SELECT SUM(DuplicateCount) FROM OverlapCheck) AS Total_Duplicate_Rows;

/*
   INTERPRETATION:
   - If Duplicate_Signatures_Found > 0: We need Deduplication (MAX) logic in DayPart query.
   - If Duplicate_Signatures_Found = 0: DayPart query is SAFE as is.
*/
