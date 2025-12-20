/*
   ===================================================================================
   DIAGNOSTIC TEST: GRANULAR 15-MINUTE BREAKDOWN
   ===================================================================================

   PURPOSE:
   Visualise raw data flow pod-by-pod, line-by-line in 15-minute intervals.
   This helps identifying duplicates and understanding the data distribution.
   
   OUTPUT:
   - Date
   - TimeBucket (15 min)
   - Pod
   - PosId
   - RawRows (How many rows in DB)
   - DedupedRows (How many rows after dedup)
   - RawAmount vs DedupedAmount
   ===================================================================================
*/

DECLARE @SiteIds NVARCHAR(MAX) = '3187';
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-02'; -- Recommend keeping range short for granular view

-- 1. Fetch Raw Data
WITH RawDataPoints AS (
    SELECT 
        sf.CalendarDate,
        sf.[DateTime],
        sf.Pod,
        sf.PosId,
        sf.TransactionCount,
        sf.Netamount,
        -- Calculate 15-min Time Bucket
        DATEADD(MINUTE, (DATEDIFF(MINUTE, 0, sf.[DateTime]) / 15) * 15, 0) AS TimeBucket
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

-- 2. Group by 15-Minute Intervals
GroupedView AS (
    SELECT
        CalendarDate AS Date,
        CAST(TimeBucket AS TIME) AS TimeStart,
        Pod,
        PosId,
        
        -- METRICS
        COUNT(*) AS Raw_Row_Count,
        
        -- Raw Totals (with duplicates)
        SUM(TransactionCount) AS Raw_Txn_Count,
        SUM(Netamount) AS Raw_Net_Amount,
        
        -- Deduped Totals (Simulated MAX logic per transaction timestamp)
        -- Note: This is an estimation for the summary view. 
        -- To be exact, we'd need to dedup first then aggregate.
        -- Here we show the raw problem:
        MIN(TransactionCount) AS Min_Txn_Per_Row,
        MAX(TransactionCount) AS Max_Txn_Per_Row
        
    FROM RawDataPoints
    GROUP BY CalendarDate, TimeBucket, Pod, PosId
)

SELECT 
    Date,
    TimeStart,
    Pod,
    PosId,
    Raw_Row_Count,
    Raw_Txn_Count,
    Raw_Net_Amount,
    
    -- Diagnostic Flags
    CASE WHEN Raw_Row_Count > 1 THEN '⚠️ DUPLICATES' ELSE 'OK' END AS Status,
    
    -- Difference Check
    (Raw_Txn_Count - Max_Txn_Per_Row) AS Calculated_Inflation
    
FROM GroupedView
ORDER BY Date, TimeStart, Pod, PosId;
