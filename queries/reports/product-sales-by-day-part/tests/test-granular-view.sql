/*
   ===================================================================================
   DIAGNOSTIC TEST: GRANULAR 15-MINUTE BREAKDOWN (DAY PART)
   ===================================================================================

   PURPOSE:
   Visualise raw data flow for Summary Rows (PosId=0) in 15-minute intervals.
   This helps identifying duplicates/overlaps in the pre-aggregated data.
   
   OUTPUT:
   - Date
   - TimeBucket (15 min)
   - RawRows (How many rows in DB)
   - RawAmount vs DedupedAmount
   ===================================================================================
*/

DECLARE @SiteIds NVARCHAR(MAX) = '3187';
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-02'; -- Short range for granular view

-- 1. Fetch Raw Data (Summary Rows Only)
WITH RawDataPoints AS (
    SELECT 
        sf.CalendarDate,
        sf.[DateTime],
        -- Calculate 15-min Time Bucket for grouping view
        DATEADD(MINUTE, (DATEDIFF(MINUTE, 0, sf.[DateTime]) / 15) * 15, 0) AS TimeBucket,
        sf.TransactionCount,
        sf.Netamount
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
      
      -- DAY PART FILTERS (Summary Rows)
      AND sf.Pod = ''
      AND ISNULL(sf.PosId, 0) = 0
),

-- 2. Group by 15-Minute Intervals
GroupedView AS (
    SELECT
        CalendarDate AS Date,
        CAST(TimeBucket AS TIME) AS TimeStart,
        
        -- METRICS
        COUNT(*) AS Raw_Row_Count,
        
        -- Raw Totals
        SUM(TransactionCount) AS Raw_Txn_Count,
        SUM(Netamount) AS Raw_Net_Amount,
        
        -- Deduped Totals (Simulated MAX logic)
        -- If Raw_Txn_Count > Max_Txn_Per_Row, we have inflation
        MAX(TransactionCount) AS Max_Txn_Per_Row
        
    FROM RawDataPoints
    GROUP BY CalendarDate, TimeBucket
)

SELECT 
    Date,
    TimeStart,
    Raw_Row_Count,
    Raw_Txn_Count,
    Max_Txn_Per_Row,
    
    -- Status
    CASE WHEN Raw_Row_Count > 1 THEN '⚠️ DUPLICATES' ELSE 'OK' END AS Status,
    
    -- Inflation Check
    (Raw_Txn_Count - Max_Txn_Per_Row) AS Calculated_Inflation
    
FROM GroupedView
ORDER BY Date, TimeStart;
