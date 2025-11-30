-- =============================================
-- Query: Product Sales By POS Type Hourly
-- Purpose: Hourly sales breakdown by Pod (Counter, Drive-Thru, Kiosk, Delivery) with YoY comparison
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2025-11-29
-- Updated: 2025-11-30
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

-- [STEP 1]: Generate 24 Hours (00-01 through 23-24)
-- Uses CTE to generate all 24 hour buckets
Hours AS (
    SELECT 0 AS HourStart
    UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14
    UNION ALL SELECT 15 UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
),

-- [STEP 2]: Get All Distinct Pods from Current Day
-- Ensures we include all pods that have data for this site/date
AllPods AS (
    SELECT DISTINCT Pod
    FROM {SalesFact}
    WHERE SiteId = @SiteId
        AND CalendarDate = @Date
        AND DatePeriodDimensionId = 15
        AND Pod IS NOT NULL
        AND Pod <> ''
        AND ProductSaleTypeId = 1
        AND ProductMenuId IS NULL
        AND TenderTypeId IS NULL
        AND OperationId IS NULL
        AND OperationKindId IS NULL
        AND SWCCashDrawerId IS NULL
        AND SaleTypeId IS NULL
),

-- [STEP 3]: Build Scaffold (Hour x Pod Grid)
-- Cross join ensures every hour has every pod, even with 0 sales
-- FIXED: Using REPLICATE instead of RIGHT for OutSystems compatibility
Scaffold AS (
    SELECT
        h.HourStart,
        -- Format hour as "00-01", "01-02", etc. (OutSystems compatible)
        REPLICATE('0', 2 - LEN(CAST(h.HourStart AS VARCHAR))) + CAST(h.HourStart AS VARCHAR) + '-' +
        REPLICATE('0', 2 - LEN(CAST((h.HourStart + 1) % 24 AS VARCHAR))) + CAST((h.HourStart + 1) % 24 AS VARCHAR) AS Hour,
        p.Pod,
        h.HourStart AS SortOrder
    FROM Hours h
    CROSS JOIN AllPods p
),

-- [STEP 4a]: CURRENT YEAR DATA (CY)
-- Fetches current day data with NZ timezone conversion
-- Groups by Hour and Pod for per-hour-per-pod breakdown
CY_RawData AS (
    SELECT
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS HourStart,
        Pod,
        SUM(NetAmount) AS CY_NetAmount,
        SUM(TransactionCount) AS CY_TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
        AND CalendarDate = @Date
        AND DatePeriodDimensionId = 15
        AND Pod IS NOT NULL
        AND Pod <> ''
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

-- [STEP 4b]: PREVIOUS YEAR DATA (PY) - 364 days back
-- Fetches prior year data for YoY comparison
-- 364 days = 52 weeks, keeps same day of week
PY_RawData AS (
    SELECT
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS HourStart,
        Pod,
        SUM(NetAmount) AS PY_NetAmount,
        SUM(TransactionCount) AS PY_TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
        AND CalendarDate = DATEADD(DAY, -364, @Date)
        AND DatePeriodDimensionId = 15
        AND Pod IS NOT NULL
        AND Pod <> ''
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

-- [STEP 5]: Merge Scaffold with CY and PY Data
-- Left joins ensure every Hour-Pod combination exists
-- ISNULL converts NULL to 0 for hours with no sales
MergedData AS (
    SELECT
        s.Hour,
        s.Pod,
        s.SortOrder,
        ISNULL(cy.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(cy.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(py.PY_NetAmount, 0) AS PY_NetAmount,
        ISNULL(py.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM Scaffold s
    LEFT JOIN CY_RawData cy ON s.HourStart = cy.HourStart AND s.Pod = cy.Pod
    LEFT JOIN PY_RawData py ON s.HourStart = py.HourStart AND s.Pod = py.Pod
),

-- [STEP 6]: Calculate Total Sales Per Hour (all pods combined)
-- Used for calculating % Total for each pod
HourlyTotals AS (
    SELECT
        Hour,
        SUM(CY_NetAmount) AS Total_CY_NetAmount,
        SUM(CY_TransactionCount) AS Total_CY_TransactionCount
    FROM MergedData
    GROUP BY Hour
),

-- [STEP 7]: Calculate Total Day Row (sum of all hours, all pods)
-- This row should match the parent screen's total
TotalDayData AS (
    SELECT
        'Total Day' AS Hour,
        Pod,
        9999 AS SortOrder,  -- Ensures Total Day appears last
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM MergedData
    GROUP BY Pod
),

-- [STEP 8]: Add Total Day Totals for % Total calculation
TotalDayTotals AS (
    SELECT
        'Total Day' AS Hour,
        SUM(CY_NetAmount) AS Total_CY_NetAmount,
        SUM(CY_TransactionCount) AS Total_CY_TransactionCount
    FROM TotalDayData
),

-- [STEP 9]: Calculate Hourly Total Rows (sum all pods per hour)
HourlyTotalRows AS (
    SELECT
        Hour,
        'Total' AS Pod,
        SortOrder - 0.5 AS SortOrder,  -- Sort Total before individual pods
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM MergedData
    GROUP BY Hour, SortOrder
),

-- [STEP 10]: Combine Hourly Data with Hourly Totals and Total Day
CombinedData AS (
    -- Hourly Total rows (one per hour)
    SELECT
        Hour, Pod, SortOrder, CY_NetAmount, CY_TransactionCount, PY_NetAmount, PY_TransactionCount
    FROM HourlyTotalRows
    UNION ALL
    -- Individual pod rows per hour
    SELECT
        Hour, Pod, SortOrder, CY_NetAmount, CY_TransactionCount, PY_NetAmount, PY_TransactionCount
    FROM MergedData
    UNION ALL
    -- Total Day Total row
    SELECT
        'Total Day' AS Hour,
        'Total' AS Pod,
        9998.5 AS SortOrder,  -- Sort Total Day Total before individual pods
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM TotalDayData
    UNION ALL
    -- Total Day individual pod rows
    SELECT
        Hour, Pod, SortOrder, CY_NetAmount, CY_TransactionCount, PY_NetAmount, PY_TransactionCount
    FROM TotalDayData
),

-- [STEP 11]: Add Totals for % Calculation
AllTotals AS (
    SELECT Hour, Total_CY_NetAmount, Total_CY_TransactionCount FROM HourlyTotals
    UNION ALL
    SELECT Hour, Total_CY_NetAmount, Total_CY_TransactionCount FROM TotalDayTotals
)

-- [STEP 12]: Final Output with Calculations
SELECT
      cd.Hour,
      cd.Pod,

      -- Sales based on view
      CASE
          WHEN (@SelectedView) = 'D' THEN cd.CY_NetAmount
          WHEN (@SelectedView) = 'G' THEN CAST(cd.CY_TransactionCount AS DECIMAL(18,2))
          WHEN (@SelectedView) = 'A' THEN
              CASE WHEN cd.CY_TransactionCount = 0 THEN 0
              ELSE cd.CY_NetAmount / cd.CY_TransactionCount END
          ELSE 0
      END AS Sales,

      -- PercentTotal (for individual pods only, 0 for Total rows)
      CASE
          WHEN cd.Pod = 'Total' THEN 0  -- Total rows don't show % Total
          WHEN (@SelectedView) = 'D' THEN
              CASE WHEN ISNULL(t.Total_CY_NetAmount, 0) = 0 THEN 0
              ELSE cd.CY_NetAmount * 100.0 / NULLIF(t.Total_CY_NetAmount, 0) END
          WHEN (@SelectedView) = 'G' THEN
              CASE WHEN ISNULL(t.Total_CY_TransactionCount, 0) = 0 THEN 0
              ELSE CAST(cd.CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / NULLIF(t.Total_CY_TransactionCount, 0) END
          WHEN (@SelectedView) = 'A' THEN 0
          ELSE 0
      END AS PercentTotal,

      -- PercentInc
      CASE
          WHEN (@SelectedView) = 'D' THEN
              CASE WHEN cd.PY_NetAmount = 0 THEN 0
              ELSE (cd.CY_NetAmount - cd.PY_NetAmount) * 100.0 / cd.PY_NetAmount END
          WHEN (@SelectedView) = 'G' THEN
              CASE WHEN cd.PY_TransactionCount = 0 THEN 0
              ELSE (CAST(cd.CY_TransactionCount AS DECIMAL(18,2)) - cd.PY_TransactionCount) * 100.0 / cd.PY_TransactionCount END
          WHEN (@SelectedView) = 'A' THEN
              CASE WHEN cd.PY_TransactionCount = 0 OR cd.CY_TransactionCount = 0 THEN 0
              WHEN (cd.PY_NetAmount / cd.PY_TransactionCount) = 0 THEN 0
              ELSE ((cd.CY_NetAmount / cd.CY_TransactionCount) - (cd.PY_NetAmount / cd.PY_TransactionCount)) * 100.0 / (cd.PY_NetAmount /
  cd.PY_TransactionCount) END
          ELSE 0
      END AS PercentInc

  FROM CombinedData cd
  LEFT JOIN AllTotals t ON cd.Hour = t.Hour

  ORDER BY cd.SortOrder ASC,
           CASE WHEN cd.Pod = 'Total' THEN 0 ELSE 1 END,  -- Total first
           cd.Pod ASC;                                     -- Then alphabetical

-- =============================================
-- OUTPUT FORMAT:
--
-- Hour     | Pod   | Sales   | PercentTotal | PercentInc
-- ---------+-------+---------+--------------+-----------
-- 00-01    | Total | 600.50  | 0.0          | 3.5
-- 00-01    | CO    | 150.50  | 25.0         | 5.2
-- 00-01    | DL    | 50.00   | 8.3          | 0.0
-- 00-01    | DT    | 300.00  | 50.0         | -2.1
-- 00-01    | KI    | 100.00  | 16.7         | 10.5
-- 01-02    | Total | 800.00  | 0.0          | 4.2
-- 01-02    | CO    | 200.00  | 25.0         | ...
-- 01-02    | DL    | 100.00  | 12.5         | ...
-- 01-02    | DT    | 400.00  | 50.0         | ...
-- 01-02    | KI    | 100.00  | 12.5         | ...
-- ...
-- Total Day| Total | 12500.00| 0.0          | 6.8
-- Total Day| CO    | 5000.00 | 40.0         | 8.5
-- Total Day| DL    | 500.00  | 4.0          | -1.5
-- Total Day| DT    | 6000.00 | 48.0         | 12.0
-- Total Day| KI    | 1000.00 | 8.0          | 5.0
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
-- - Pod (Text) - "Total", "CO", "DL", "DT", "KI" (alphabetical after Total)
-- - Sales (Decimal) - Based on SelectedView (D/G/A)
-- - PercentTotal (Decimal) - % of hour total (0 for Total rows)
-- - PercentInc (Decimal) - YoY % increase
--
-- =============================================
-- STATUS: READY FOR OUTSYSTEMS
-- Fixed: Using REPLICATE instead of RIGHT for compatibility
-- Fixed: Added Total rows for each hour and Total Day
-- =============================================
