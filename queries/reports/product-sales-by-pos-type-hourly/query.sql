-- =============================================
-- Query: Product Sales By POS Type Hourly
-- Purpose: Hourly sales breakdown by Pod (Counter, Drive-Thru, Kiosk, Delivery) with YoY comparison
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2025-11-29
-- Updated: 2025-12-10 - Performance optimization (UNION ALL approach for parallel execution)
-- =============================================

-- ⚠️ NOTE: When using in OutSystems Advanced SQL Block:
-- 1. REMOVE all DECLARE statements below (they don't work in OutSystems)
-- 2. Add Input Parameters in OutSystems: SiteId (Long Integer), Date (Date), SelectedView (Text)
-- 3. Set all parameters to Expand Inline = No

-- Parameters (for local SQL Server testing only - comment out for OutSystems)
DECLARE @SiteId BIGINT = 3187;              -- Site ID to filter
DECLARE @Date DATE = '2025-11-29';          -- NZ Date (single day)
DECLARE @SelectedView VARCHAR(1) = 'D';     -- 'D' = Sales (NetAmount), 'G' = GC (TransactionCount), 'A' = Av Chq (NetAmount/TransactionCount)

-- =============================================
-- MAIN QUERY: HOURLY SALES BY POS TYPE
-- Returns one row per Hour-Pod combination + Total row per hour
-- Output: Long format (24 hours x (N pods + 1 Total) = ~120 rows for 4 pods)
-- =============================================

WITH

-- [STEP 0]: Parameters & Constants
-- We wrap standard inputs to ensure OutSystems binds them correctly
InputVar AS (
    SELECT @SelectedView AS Val
),
-- Pre-calculate PY Date to avoid recalculating it on every row
Calculations AS (
    SELECT DATEADD(DAY, -364, @Date) AS PYDate
),

-- [STEP 1]: Generate 24 Hours
Hours AS (
    SELECT 0 AS HourStart
    UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14
    UNION ALL SELECT 15 UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
),

-- [STEP 2]: Fetch Data (THE OPTIMIZATION)
-- We use UNION ALL to force SQL Server to use the Index on CalendarDate twice efficiently.
RawDataPoints AS (
    -- QUERY A: Current Year (Index Seek)
    SELECT
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS HourStart,
        Pod,
        NetAmount AS CY_NetAmount,
        TransactionCount AS CY_TransactionCount,
        0 AS PY_NetAmount,
        0 AS PY_TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
      AND CalendarDate = @Date -- Direct Index Hit
      AND DatePeriodDimensionId = 15
      AND Pod IS NOT NULL AND Pod <> ''
      AND ProductSaleTypeId = 1
      AND ProductMenuId IS NULL
      AND TenderTypeId IS NULL
      AND OperationId IS NULL
      AND OperationKindId IS NULL
      AND SWCCashDrawerId IS NULL
      AND SaleTypeId IS NULL

    UNION ALL

    -- QUERY B: Previous Year (Index Seek)
    SELECT
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS HourStart,
        Pod,
        0, 0, -- CY is 0
        NetAmount,
        TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
      AND CalendarDate = (SELECT PYDate FROM Calculations) -- Direct Index Hit on calculated date
      AND DatePeriodDimensionId = 15
      AND Pod IS NOT NULL AND Pod <> ''
      AND ProductSaleTypeId = 1
      AND ProductMenuId IS NULL
      AND TenderTypeId IS NULL
      AND OperationId IS NULL
      AND OperationKindId IS NULL
      AND SWCCashDrawerId IS NULL
      AND SaleTypeId IS NULL
),

-- [STEP 3]: Aggregate the Points
AggregatedData AS (
    SELECT
        HourStart,
        Pod,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM RawDataPoints
    GROUP BY HourStart, Pod
),

-- [STEP 4]: Get Active Pods (Only those with CY data)
ActivePods AS (
    SELECT DISTINCT Pod
    FROM AggregatedData
    WHERE CY_NetAmount <> 0 OR CY_TransactionCount > 0
),

-- [STEP 5]: Build Scaffold (Hour x Pod Grid)
Scaffold AS (
    SELECT
        h.HourStart,
        -- Format hour as "00-01", "23-24"
        REPLICATE('0', 2 - LEN(CAST(h.HourStart AS VARCHAR))) + CAST(h.HourStart AS VARCHAR) + '-' +
        REPLICATE('0', 2 - LEN(CAST((h.HourStart + 1) AS VARCHAR))) + CAST((h.HourStart + 1) AS VARCHAR) AS Hour,
        p.Pod,
        -- Sort logic
        h.HourStart + ((ROW_NUMBER() OVER (PARTITION BY h.HourStart ORDER BY p.Pod) + 1) * 0.01) AS SortOrder
    FROM Hours h
    CROSS JOIN ActivePods p
),

-- [STEP 6]: Merge Scaffold with Aggregated Data
MergedData AS (
    SELECT
        s.HourStart,
        s.Hour,
        s.Pod,
        s.SortOrder,
        ISNULL(ad.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(ad.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(ad.PY_NetAmount, 0) AS PY_NetAmount,
        ISNULL(ad.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM Scaffold s
    LEFT JOIN AggregatedData ad ON s.HourStart = ad.HourStart AND s.Pod = ad.Pod
),

-- [STEP 7]: Calculate Denominators (Window Functions)
EnrichedData AS (
    SELECT
        m.*,
        SUM(CY_NetAmount) OVER(PARTITION BY Hour) as Hourly_Total_Net,
        SUM(CY_TransactionCount) OVER(PARTITION BY Hour) as Hourly_Total_Trans,
        SUM(CY_NetAmount) OVER() as Day_Total_Net,
        SUM(CY_TransactionCount) OVER() as Day_Total_Trans
    FROM MergedData m
),

-- [STEP 8]: Generate Final Rows
FinalRows AS (
    -- 1. Individual Pod Rows
    SELECT
        Hour, Pod, SortOrder,
        CY_NetAmount, CY_TransactionCount, PY_NetAmount, PY_TransactionCount,
        Hourly_Total_Net as Denom_Net, Hourly_Total_Trans as Denom_Trans
    FROM EnrichedData

    UNION ALL

    -- 2. Hourly Total Rows
    SELECT
        Hour, 'Total', HourStart + 0.01,
        SUM(CY_NetAmount), SUM(CY_TransactionCount), SUM(PY_NetAmount), SUM(PY_TransactionCount),
        NULL, NULL
    FROM EnrichedData
    GROUP BY Hour, HourStart

    UNION ALL

    -- 3. Grand Total Row
    SELECT
        'Total Day', 'Total', 9999.01,
        SUM(CY_NetAmount), SUM(CY_TransactionCount), SUM(PY_NetAmount), SUM(PY_TransactionCount),
        NULL, NULL
    FROM EnrichedData

    UNION ALL

    -- 4. Total Day per Pod Rows
    SELECT
        'Total Day', Pod,
        9999 + ((ROW_NUMBER() OVER (ORDER BY Pod) + 1) * 0.01),
        SUM(CY_NetAmount), SUM(CY_TransactionCount), SUM(PY_NetAmount), SUM(PY_TransactionCount),
        MAX(Day_Total_Net), MAX(Day_Total_Trans)
    FROM EnrichedData
    GROUP BY Pod
)

-- [STEP 9]: Final Output
SELECT
      fr.Hour,
      fr.Pod,

      -- Sales
      CASE (SELECT Val FROM InputVar)
          WHEN 'D' THEN fr.CY_NetAmount
          WHEN 'G' THEN CAST(fr.CY_TransactionCount AS DECIMAL(18,2))
          WHEN 'A' THEN
              CASE WHEN fr.CY_TransactionCount = 0 THEN 0
              ELSE fr.CY_NetAmount / fr.CY_TransactionCount END
          ELSE 0
      END AS Sales,

      -- PercentTotal
      CASE
          WHEN fr.Pod = 'Total' THEN 0
          WHEN (SELECT Val FROM InputVar) = 'D' THEN
              CASE WHEN ISNULL(fr.Denom_Net, 0) = 0 THEN 0
              ELSE fr.CY_NetAmount * 100.0 / NULLIF(fr.Denom_Net, 0) END
          WHEN (SELECT Val FROM InputVar) = 'G' THEN
              CASE WHEN ISNULL(fr.Denom_Trans, 0) = 0 THEN 0
              ELSE CAST(fr.CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / NULLIF(fr.Denom_Trans, 0) END
          ELSE 0
      END AS PercentTotal,

      -- PercentInc
      CASE (SELECT Val FROM InputVar)
          WHEN 'D' THEN
              CASE WHEN fr.PY_NetAmount = 0 THEN 0
              ELSE (fr.CY_NetAmount - fr.PY_NetAmount) * 100.0 / fr.PY_NetAmount END
          WHEN 'G' THEN
              CASE WHEN fr.PY_TransactionCount = 0 THEN 0
              ELSE (CAST(fr.CY_TransactionCount AS DECIMAL(18,2)) - fr.PY_TransactionCount) * 100.0 / fr.PY_TransactionCount END
          WHEN 'A' THEN
              CASE WHEN fr.PY_TransactionCount = 0 OR fr.CY_TransactionCount = 0 THEN 0
              WHEN (fr.PY_NetAmount / fr.PY_TransactionCount) = 0 THEN 0
              ELSE ((fr.CY_NetAmount / fr.CY_TransactionCount) - (fr.PY_NetAmount / fr.PY_TransactionCount)) * 100.0 / (fr.PY_NetAmount / fr.PY_TransactionCount) END
          ELSE 0
      END AS PercentInc

  FROM FinalRows fr
  ORDER BY fr.SortOrder ASC,
           CASE WHEN fr.Pod = 'Total' THEN 0 ELSE 1 END,
           fr.Pod ASC
  OPTION (MAXRECURSION 1000, RECOMPILE);

-- =============================================
-- OUTPUT FORMAT:
--
-- Hour     | Pod   | Sales   | PercentTotal | PercentInc
-- ---------+-------+---------+--------------+-----------
-- 00-01    | Total | 600.50  | 0.0          | 3.5
-- 00-01    | CSO   | 150.50  | 25.0         | 5.2
-- 00-01    | DELIVERY | 50.00 | 8.3        | 0.0
-- 00-01    | DT    | 300.00  | 50.0         | -2.1
-- 00-01    | FC    | 100.00  | 16.7         | 10.5
-- 01-02    | Total | 800.00  | 0.0          | 4.2
-- 01-02    | CSO   | 200.00  | 25.0         | ...
-- 01-02    | DELIVERY | 100.00 | 12.5      | ...
-- 01-02    | DT    | 400.00  | 50.0         | ...
-- 01-02    | FC    | 100.00  | 12.5         | ...
-- ...
-- Total Day| Total | 12500.00| 0.0          | 6.8
-- Total Day| CSO   | 5000.00 | 40.0         | 8.5
-- Total Day| DELIVERY | 500.00 | 4.0        | -1.5
-- Total Day| DT    | 6000.00 | 48.0         | 12.0
-- Total Day| FC    | 1000.00 | 8.0          | 5.0
--
-- Output: 24 hours × 5 rows (Total + 4 pods) + Total Day × 5 rows = 125 rows
--
-- =============================================
-- OUTSYSTEMS SETUP:
--
-- Input Parameters (Expand Inline = No):
-- - SiteId (Long Integer) = 3187
-- - Date (Date) = #2025-11-29#
-- - SelectedView (Text) = "D"
--
-- Output Structure:
-- - Hour (Text) - "00-01", "01-02", ..., "23-24", "Total Day"
-- - Pod (Text) - "Total", "CSO", "DELIVERY", "DT", "FC" (alphabetical after Total)
-- - Sales (Decimal) - Based on SelectedView (D/G/A)
-- - PercentTotal (Decimal) - % of hour total (0 for Total rows)
-- - PercentInc (Decimal) - YoY % increase
--
-- =============================================
-- OPTIMIZATIONS APPLIED:
-- 1. ✅ UNION ALL approach - Forces parallel index seeks on CY and PY dates
-- 2. ✅ Pre-calculated PY date - Calculated once in Calculations CTE
-- 3. ✅ Pre-aggregation - Aggregate raw data before building scaffold
-- 4. ✅ Active pods detection - Only shows pods with CY activity
-- 5. ✅ Window functions - Pre-calculate totals without extra joins
-- 6. ✅ RECOMPILE hint - Optimal execution plan for each run
--
-- PERFORMANCE: Optimized for minimal database hits and cleaner execution plan
-- =============================================
-- STATUS: READY FOR OUTSYSTEMS - OPTIMIZED
-- =============================================
