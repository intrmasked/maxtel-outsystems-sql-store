/*
   ===================================================================================
   DIAGNOSTIC TEST: CHECK FOR DOUBLE COUNTING / OVERLAP IN POS QUERY
   ===================================================================================

   PURPOSE:
   Determine if the Parent POS Query logic is causing any row in SalesFact
   to be counted more than once (e.g., due to joins or filter logic).
   
   METHOD:
   1. Select raw rows matching the Parent Query filters.
   2. Group by Unique ID (Transaction + Line Item ID if available, or clustered index).
   3. Check if any ID appears > 1 time.
   
   NOTE: SalesFact usually has composite PK: (SiteId, Date, TransactionId, LineId, etc.)
   We will group by the most granular columns available.
   ===================================================================================
*/

DECLARE @SiteIds NVARCHAR(MAX) = '3187';
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';

-- 1. Simulate the Parent Query Logic (RawDataPoints CTE)
-- We select the unique identifier columns for each row that WOULD be included
WITH TargetRows AS (
    SELECT 
        sf.SiteId,
        sf.CalendarDate,
        sf.[DateTime],
        sf.PosId,
        sf.TransactionNumber, -- Assuming this exists (or TransactionId)
        sf.ProductMenuId,     -- Just to be safe
        sf.Netamount,
        
        -- Generate a unique hash or row identifier if no single PK exists
        -- (SiteId + DateTime + PosId + TransactionNumber is usually unique enough for a check)
        CONCAT(sf.SiteId, '|', FORMAT(sf.[DateTime], 'yyyyMMddHHmmss'), '|', sf.PosId, '|', sf.TransactionNumber) AS RowSignature
    FROM {SalesFact} sf
    WHERE sf.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
      AND sf.CalendarDate BETWEEN @StartDate AND @EndDate
      -- SAME FILTERS AS PARENT QUERY
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
)

-- 2. Check for Duplicates
SELECT 
    RowSignature,
    COUNT(*) AS DuplicateCount,
    MIN(CalendarDate) AS SampleDate,
    MIN(SiteId) AS SiteId
FROM TargetRows
GROUP BY RowSignature
HAVING COUNT(*) > 1
ORDER BY DuplicateCount DESC;

/*
   INTERPRETATION:
   - If this returns 0 rows: The Parent Query logic is clean. NO double counting of raw rows.
   - If this returns rows: You have duplicate data in SalesFact matching these filters, 
     OR the filters are not specific enough (e.g. multiple rows per transaction).
*/
