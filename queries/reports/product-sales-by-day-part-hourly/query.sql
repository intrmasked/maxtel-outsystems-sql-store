/*
   ===================================================================================
   QUERY: PRODUCT SALES BY DAY PART - HOURLY BREAKDOWN
   ===================================================================================

   PURPOSE:
   Returns hourly sales breakdown for a single day (24 hourly rows + 4 day part totals + 1 Total row = 29 rows).
   Shows how sales are distributed across each hour of the day with YoY comparison.
   Includes day part total rows after each day part for easy aggregation.

   INPUT PARAMETERS:
   - @Date: Single date for the hourly breakdown.
   - @SiteId: The specific location ID.
   - @SelectedView: Controls the metric displayed:
       'D' -> Net Amount ($ Sales)
       'G' -> Transaction Count (Guest Counts)
       'A' -> Average Check (Net Amount / Transaction Count)

   HOUR FORMAT:
   - 00-01: Midnight to 1 AM (0:00 - 0:59)
   - 01-02: 1 AM to 2 AM (1:00 - 1:59)
   - ...
   - 23-24: 11 PM to Midnight (23:00 - 23:59)
   - Total: Sum of all 24 hours

   KEY FEATURES:
   1. DateTime converted to NZ timezone (NZDT = UTC+13, NZST = UTC+12)
   2. Aggregate level: Pod = '' and PosId = 0 (site-wide totals)
   3. ProductSaleTypeId = 1 (product sales only)
   4. Total row should align with parent screen day totals
   5. DayPartLabel column: Auto-classifies each hour into day parts (Overnight/Breakfast/Day/Night)
   6. Day Part Total rows: Overnight Total, Breakfast Total, Day Total, Night Total (appear after last hour of each part)

   KEY OPTIMIZATIONS:
   1. SEPARATED CY/PY FETCH: Prevents double-counting from conditional CASE logic
   2. EARLY FILTERING: All WHERE conditions applied before aggregation for index pushdown
   3. WINDOW FUNCTIONS: Calculate daily totals without extra joins

   ===================================================================================
*/

-- Parameters (for local SQL Server testing)
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-25';
DECLARE @SelectedView VARCHAR(1) = 'D';  -- 'D' = Dollars, 'G' = Guests, 'A' = Average

WITH

-- [STEP 1]: Handle Parameters (OutSystems quirk fix)
InputVar AS (
    SELECT @SelectedView AS Val
),

-- [STEP 2]: Generate 24-Hour Scaffold
-- Creates rows for 00-01, 01-02, ..., 23-24
Hours AS (
    SELECT 0 AS HourNum UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
    UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11
    UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
    UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
),
HourLabels AS (
    SELECT
        HourNum,
        -- Format: "00-01", "01-02", ..., "23-24"
        REPLICATE('0', 2 - LEN(CAST(HourNum AS VARCHAR))) + CAST(HourNum AS VARCHAR) + '-' +
        REPLICATE('0', 2 - LEN(CAST(HourNum + 1 AS VARCHAR))) + CAST(HourNum + 1 AS VARCHAR) AS HourLabel,
        -- Day Part Classification
        CASE
            WHEN HourNum >= 0 AND HourNum < 5 THEN 'Overnight (00-05)'
            WHEN HourNum >= 5 AND HourNum < 11 THEN 'Breakfast (05-11)'
            WHEN HourNum >= 11 AND HourNum < 17 THEN 'Day (11-17)'
            WHEN HourNum >= 17 THEN 'Night (17-24)'
        END AS DayPartLabel,
        HourNum + 1 AS SortOrder  -- 1-24 for hour rows, 0 reserved for Total
    FROM Hours
),

-- [STEP 3a]: CURRENT YEAR DATA ONLY
-- Fetches CY data independently (no mixed CASE logic with PY)
-- DateTime converted to NZ timezone, then extract hour (0-23)
CY_RawData AS (
    SELECT
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS HourNum,
        SUM(NetAmount) AS CY_NetAmount,
        SUM(TransactionCount) AS CY_TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
      AND CalendarDate = @Date
      -- [EARLY FILTERING FOR INDEX PUSHDOWN]
      -- Critical filters applied FIRST so SQL Server uses optimal index
      AND DatePeriodDimensionId = 15
      AND ProductMenuId IS NULL
      AND ProductSaleTypeId = 1
      AND TenderTypeId IS NULL
      AND OperationId IS NULL
      AND OperationKindId IS NULL
      AND SWCCashDrawerId IS NULL
      AND SaleTypeId IS NULL
      -- [AGGREGATE LEVEL FILTERS]
      -- Pod = '' and PosId = 0 for site-wide totals (matching parent query)
      AND Pod = ''
      AND ISNULL(PosId,0) = 0
    GROUP BY DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time'))
),

-- [STEP 3b]: PREVIOUS YEAR DATA (shifted forward by 364 days)
-- Fetches PY data completely independently
-- Shifted by 364 days (52 weeks) to align day-of-week (e.g., Monday to Monday)
-- DateTime converted to NZ timezone
PY_RawData AS (
    SELECT
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS HourNum,
        SUM(NetAmount) AS PY_NetAmount,
        SUM(TransactionCount) AS PY_TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
      AND CalendarDate = DATEADD(DAY, -364, @Date)
      -- [EARLY FILTERING FOR INDEX PUSHDOWN]
      AND DatePeriodDimensionId = 15
      AND ProductMenuId IS NULL
      AND ProductSaleTypeId = 1
      AND TenderTypeId IS NULL
      AND OperationId IS NULL
      AND OperationKindId IS NULL
      AND SWCCashDrawerId IS NULL
      AND SaleTypeId IS NULL
      -- [AGGREGATE LEVEL FILTERS]
      AND Pod = ''
      AND ISNULL(PosId,0) = 0
    GROUP BY DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time'))
),

-- [STEP 4]: Merge Scaffold with CY and PY Data
-- Left joins ensure every hour exists with 0 if no sales
-- ISNULL converts NULL to 0.00 for empty cells
CleanedData AS (
    SELECT
        h.HourNum,
        h.HourLabel,
        h.DayPartLabel,
        h.SortOrder,
        ISNULL(cy.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(cy.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(py.PY_NetAmount, 0) AS PY_NetAmount,
        ISNULL(py.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM HourLabels h
    LEFT JOIN CY_RawData cy ON h.HourNum = cy.HourNum
    LEFT JOIN PY_RawData py ON h.HourNum = py.HourNum
),

-- [STEP 5]: Calculate Daily Totals (00-24)
-- Sums all 24 hours to show full-day totals
-- This row should mathematically equal the sum of all 24 hours
-- Should align with parent screen day totals
TotalData AS (
    SELECT
        NULL AS HourNum,
        'Total' AS HourLabel,
        'Total (00-24)' AS DayPartLabel,
        0 AS SortOrder,  -- 0 ensures Total appears first in sort
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM CleanedData
),

-- [STEP 6]: Calculate Day Part Totals
-- Sums hours within each day part and creates total rows
-- These rows appear after the last hour of each day part
DayPartTotals AS (
    SELECT
        NULL AS HourNum,
        CASE DayPartLabel
            WHEN 'Overnight (00-05)' THEN 'Overnight Total'
            WHEN 'Breakfast (05-11)' THEN 'Breakfast Total'
            WHEN 'Day (11-17)' THEN 'Day Total'
            WHEN 'Night (17-24)' THEN 'Night Total'
        END AS HourLabel,
        DayPartLabel,
        -- SortOrder places day part total after last hour of that day part
        CASE DayPartLabel
            WHEN 'Overnight (00-05)' THEN 5.5   -- After 04-05 (SortOrder 5)
            WHEN 'Breakfast (05-11)' THEN 11.5  -- After 10-11 (SortOrder 11)
            WHEN 'Day (11-17)' THEN 17.5        -- After 16-17 (SortOrder 17)
            WHEN 'Night (17-24)' THEN 24.5      -- After 23-24 (SortOrder 24)
        END AS SortOrder,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM CleanedData
    GROUP BY DayPartLabel
),

-- [STEP 7]: Combine Individual Hours with Total Row and Day Part Totals
CombinedSet AS (
    SELECT * FROM CleanedData
    UNION ALL
    SELECT * FROM TotalData
    UNION ALL
    SELECT * FROM DayPartTotals
),

-- [STEP 8]: Calculate Daily Total for % Total Calculation
-- Use window function to get daily total across all rows
DailyTotals AS (
    SELECT
        HourLabel,
        DayPartLabel,
        SortOrder,
        CY_NetAmount,
        CY_TransactionCount,
        PY_NetAmount,
        PY_TransactionCount,
        -- Daily totals (from Total row where SortOrder = 0)
        MAX(CASE WHEN SortOrder = 0 THEN CY_NetAmount ELSE 0 END) OVER () AS DailyTotal_Net,
        MAX(CASE WHEN SortOrder = 0 THEN CY_TransactionCount ELSE 0 END) OVER () AS DailyTotal_Txn
    FROM CombinedSet
)

-- [STEP 9]: Calculate Final Metrics & Project Output
SELECT
    HourLabel AS Hour,
    DayPartLabel,

    -- [CALC 1: Main Value]
    -- Dynamically selects metric based on @SelectedView parameter
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN CY_NetAmount              -- Dollar Amount ($)
        WHEN 'G' THEN CAST(CY_TransactionCount AS DECIMAL(18,2))  -- Guest Count (#)
        WHEN 'A' THEN CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END  -- Average Check ($)
        ELSE 0
    END AS Value,

    -- [CALC 2: Percent of Daily Total]
    -- Shows what % of daily total this hour represents
    -- Returns 0 for Average view (statistically invalid)
    -- For Total row, returns 100%
    CASE
        WHEN (SELECT Val FROM InputVar) = 'A' THEN 0
        WHEN SortOrder = 0 THEN 100  -- Total row always 100%
        WHEN (SELECT Val FROM InputVar) = 'D' THEN
             CASE WHEN DailyTotal_Net = 0 THEN 0
                  ELSE CY_NetAmount * 100.0 / NULLIF(DailyTotal_Net, 0) END
        WHEN (SELECT Val FROM InputVar) = 'G' THEN
             CASE WHEN DailyTotal_Txn = 0 THEN 0
                  ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / NULLIF(DailyTotal_Txn, 0) END
        ELSE 0
    END AS PercentTotal,

    -- [CALC 3: Year-over-Year Growth %]
    -- Formula: (CY - PY) / PY * 100
    -- Handles division by zero; returns 0 if no prior year data exists
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN
            CASE WHEN PY_NetAmount = 0 THEN 0
            ELSE (CY_NetAmount - PY_NetAmount) * 100.0 / PY_NetAmount END
        WHEN 'G' THEN
            CASE WHEN PY_TransactionCount = 0 THEN 0
            ELSE (CAST(CY_TransactionCount AS DECIMAL(18,2)) - PY_TransactionCount) * 100.0 / PY_TransactionCount END
        WHEN 'A' THEN
            CASE
                WHEN PY_TransactionCount = 0 OR CY_TransactionCount = 0 THEN 0
                WHEN (PY_NetAmount / PY_TransactionCount) = 0 THEN 0
                ELSE ((CY_NetAmount / CY_TransactionCount) - (PY_NetAmount / PY_TransactionCount)) * 100.0 / (PY_NetAmount / PY_TransactionCount)
            END
        ELSE 0
    END AS PercentInc,

    SortOrder

FROM DailyTotals
ORDER BY SortOrder ASC;
