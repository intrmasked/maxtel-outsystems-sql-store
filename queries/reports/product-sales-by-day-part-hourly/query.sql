/*
   ===================================================================================
   QUERY: PRODUCT SALES BY DAY PART - HOURLY BREAKDOWN (OPTIMIZED + InputVar Fix)
   ===================================================================================

   PURPOSE:
   Returns hourly sales breakdown for a single day (24 hourly rows + 4 day part totals + 1 Total row = 29 rows).
   Shows how sales are distributed across each hour of the day with YoY comparison.
   Includes day part total rows after each day part for easy aggregation.

   INPUT PARAMETERS (OutSystems):
   - @SiteId: The specific location ID.
   - @Date: Single date for the hourly breakdown.
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
   1. INPUTVAR CTE PATTERN: Fixes OutSystems "Lazy Parser" parameter binding issue
   2. SINGLE TABLE SCAN: Fetches CY and PY data in one pass using conditional SUM
   3. EARLY FILTERING: All WHERE conditions applied before aggregation for index pushdown
   4. WINDOW FUNCTIONS: Calculate daily totals without extra joins
   5. RECOMPILE HINT: Ensures optimal execution plan for each parameter set

   ===================================================================================
*/

/*
   ===================================================================================
   OUTSYSTEMS SETUP INSTRUCTIONS
   ===================================================================================

   In OutSystems Advanced SQL Block, define these Input Parameters:

   1. SiteId (Long Integer) - Expand Inline: No
   2. Date (Date) - Expand Inline: No
   3. SelectedView (Text) - Expand Inline: No

   OutSystems will automatically convert these to @SiteId, @Date, @SelectedView

   FOR LOCAL SQL SERVER TESTING ONLY, uncomment these lines:
   -- DECLARE @SiteId BIGINT = 3187;
   -- DECLARE @Date DATE = '2025-11-25';
   -- DECLARE @SelectedView VARCHAR(1) = 'D';

   ===================================================================================
*/

WITH

-- [STEP 0]: INPUTVAR PATTERN - SAFE PARAMETER BINDING
-- CRITICAL: This CTE MUST be first to fix OutSystems "Lazy Parser" bug
-- OutSystems scans queries top-down; if parameters aren't seen early, it stops tracking them
-- We select the inputs and calculate PY Date here, once, at the very top.
InputVars AS (
    SELECT
        @Date AS CurrentDate,
        DATEADD(DAY, -364, @Date) AS PrevDate,
        @SiteId AS SiteIdVal,
        @SelectedView AS ViewVal
),

-- [STEP 1]: Generate 24-Hour Scaffold
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
        -- Format: "00-01", "01-02", ..., "23-24" (OutSystems compatible - uses REPLICATE not RIGHT)
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

-- [STEP 2]: COMBINED DATA FETCH (Single Pass Optimization)
-- Fetches both CY and PY data in one scan of the table
-- Uses CROSS JOIN with InputVars to safely reference parameters
RawDataCombined AS (
    SELECT
        -- CPU INTENSIVE: Only calculate Hour once per row
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS HourNum,

        -- Conditional Aggregation using InputVars CTE columns
        SUM(CASE WHEN CalendarDate = v.CurrentDate THEN NetAmount ELSE 0 END) AS CY_NetAmount,
        SUM(CASE WHEN CalendarDate = v.CurrentDate THEN TransactionCount ELSE 0 END) AS CY_TransactionCount,

        SUM(CASE WHEN CalendarDate = v.PrevDate THEN NetAmount ELSE 0 END) AS PY_NetAmount,
        SUM(CASE WHEN CalendarDate = v.PrevDate THEN TransactionCount ELSE 0 END) AS PY_TransactionCount
    FROM {SalesFact}, InputVars v -- CROSS JOIN simulates using variables
    WHERE SiteId = v.SiteIdVal
      AND CalendarDate IN (v.CurrentDate, v.PrevDate) -- Filters for both dates simultaneously
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

-- [STEP 3]: Merge Scaffold with Combined Data
-- Left joins ensure every hour exists with 0 if no sales
-- ISNULL converts NULL to 0.00 for empty cells
CleanedData AS (
    SELECT
        h.HourNum,
        h.HourLabel,
        h.DayPartLabel,
        h.SortOrder,
        ISNULL(r.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(r.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(r.PY_NetAmount, 0) AS PY_NetAmount,
        ISNULL(r.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM HourLabels h
    LEFT JOIN RawDataCombined r ON h.HourNum = r.HourNum
),

-- [STEP 4]: Calculate Daily Totals (00-24)
-- Sums all 24 hours to show full-day totals
-- This row should mathematically equal the sum of all 24 hours
-- Should align with parent screen day totals
TotalData AS (
    SELECT
        NULL AS HourNum,
        'TotalDay' AS HourLabel,
        'Total (00-24)' AS DayPartLabel,
        29 AS SortOrder,  -- 29 ensures Total appears last (after all hours and day part totals)
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM CleanedData
),

-- [STEP 5]: Calculate Day Part Totals
-- Sums hours within each day part and creates total rows
-- These rows appear after all 24 hours, before TotalDay
DayPartTotals AS (
    SELECT
        NULL AS HourNum,
        CASE DayPartLabel
            WHEN 'Overnight (00-05)' THEN 'Overnight TotalDay'
            WHEN 'Breakfast (05-11)' THEN 'Breakfast TotalDay'
            WHEN 'Day (11-17)' THEN 'Day TotalDay'
            WHEN 'Night (17-24)' THEN 'Night TotalDay'
        END AS HourLabel,
        DayPartLabel,
        -- SortOrder: 25-28 (after all 24 hours, before TotalDay at 29)
        CASE DayPartLabel
            WHEN 'Overnight (00-05)' THEN 25   -- After all hours
            WHEN 'Breakfast (05-11)' THEN 26
            WHEN 'Day (11-17)' THEN 27
            WHEN 'Night (17-24)' THEN 28       -- Before TotalDay (29)
        END AS SortOrder,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM CleanedData
    GROUP BY DayPartLabel
),

-- [STEP 6]: Combine and Calculate Window Metrics
-- Combines all row types and calculates daily totals via window functions
FinalSet AS (
    SELECT
        HourLabel,
        DayPartLabel,
        SortOrder,
        CY_NetAmount,
        CY_TransactionCount,
        PY_NetAmount,
        PY_TransactionCount,

        -- Window functions calculate daily total across the result set
        MAX(CASE WHEN SortOrder = 29 THEN CY_NetAmount ELSE 0 END) OVER () AS DailyTotal_Net,
        MAX(CASE WHEN SortOrder = 29 THEN CY_TransactionCount ELSE 0 END) OVER () AS DailyTotal_Txn
    FROM (
        SELECT * FROM CleanedData
        UNION ALL
        SELECT * FROM TotalData
        UNION ALL
        SELECT * FROM DayPartTotals
    ) Combined
)

-- [STEP 7]: Calculate Final Metrics & Project Output
-- OutSystems Output Structure: Hour, DayPartLabel, Sales, PercentTotal, PercentInc (5 columns)
SELECT
    HourLabel AS Hour,
    DayPartLabel,

    -- [CALC 1: Main Value]
    -- Dynamically selects metric based on @SelectedView parameter
    -- Uses InputVars subquery pattern for safe parameter binding
    CASE (SELECT ViewVal FROM InputVars)
        WHEN 'D' THEN CY_NetAmount              -- Dollar Amount ($)
        WHEN 'G' THEN CAST(CY_TransactionCount AS DECIMAL(18,2))  -- Guest Count (#)
        WHEN 'A' THEN CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END  -- Average Check ($)
        ELSE 0
    END AS Sales,

    -- [CALC 2: Percent of Daily Total]
    -- Shows what % of daily total this hour represents
    -- Returns 0 for Average view (statistically invalid)
    -- For Total row, returns 100%
    CASE
        WHEN (SELECT ViewVal FROM InputVars) = 'A' THEN 0
        WHEN SortOrder = 29 THEN 100  -- Total Day row always 100%
        WHEN (SELECT ViewVal FROM InputVars) = 'D' THEN
             CASE WHEN DailyTotal_Net = 0 THEN 0
                  ELSE CY_NetAmount * 100.0 / NULLIF(DailyTotal_Net, 0) END
        WHEN (SELECT ViewVal FROM InputVars) = 'G' THEN
             CASE WHEN DailyTotal_Txn = 0 THEN 0
                  ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / NULLIF(DailyTotal_Txn, 0) END
        ELSE 0
    END AS PercentTotal,

    -- [CALC 3: Year-over-Year Growth %]
    -- Formula: (CY - PY) / PY * 100
    -- Handles division by zero; returns 0 if no prior year data exists
    CASE (SELECT ViewVal FROM InputVars)
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
    END AS PercentInc

FROM FinalSet
ORDER BY SortOrder ASC
OPTION (RECOMPILE);  -- Ensures optimal execution plan for each parameter set
