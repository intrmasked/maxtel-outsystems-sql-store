/*
   ===================================================================================
   QUERY: PRODUCT SALES BY DAY PART (HOUR-BASED BUCKETS) - MULTI-SITE SUPPORT
   ===================================================================================

   PURPOSE:
   Returns sales/transaction data grouped by 4 day-part time buckets, date, and site.
   Shows how sales are distributed across different times of day with YoY comparison.
   Supports single-site or multi-site reporting with active/inactive filtering.

   INPUT PARAMETERS:
   - @StartDate, @EndDate: The date range for the report.
   - @SiteIds: Comma-separated list of Site IDs (e.g., '123,456,789').
               OutSystems handles tenant filtering and passes pre-filtered list.
   - @SelectedView: Controls the metric displayed:
       'D' -> Net Amount ($ Sales)
       'G' -> Transaction Count (Guest Counts)
       'A' -> Average Check (Net Amount / Transaction Count)

   DAY PART DEFINITIONS:
   - Overnight (00-05): Graveyard shift sales (0:00 AM - 4:59 AM)
   - Breakfast (05-11): Morning service (5:00 AM - 10:59 AM)
   - Day (11-17): Lunch & afternoon (11:00 AM - 4:59 PM)
   - Night (17-24): Dinner & evening (5:00 PM - 11:59 PM)

   KEY CHANGES:
   1. DateTime converted to NZ timezone (NZDT = UTC+13, NZST = UTC+12)
   2. Pod filter: Pod = '' (aggregate level)
   3. ProductSaleTypeId = 1 (product sales only)
   4. Multi-site support: @SiteIds accepts comma-separated list
   5. Tenant filtering: Handled by OutSystems application layer
   6. Site names included in output via Site table join

   KEY OPTIMIZATIONS:
   1. SEPARATED CY/PY FETCH: Prevents double-counting from conditional CASE logic
   2. EARLY FILTERING: All WHERE conditions applied before aggregation for index pushdown
   3. OUTSYSTEMS TENANT HANDLING: Application layer pre-filters sites (faster, cleaner)
   4. SCAFFOLD PATTERN: Date x DayPart x Site grid ensures complete output

   ===================================================================================
*/

DECLARE @SiteIds NVARCHAR(MAX) = '3187,3188,3189';  -- Comma-separated Site IDs
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';
DECLARE @SelectedView VARCHAR(1) = 'D';

WITH

-- [STEP 0]: InputVar CTE (CRITICAL FOR OUTSYSTEMS!)
-- OutSystems "lazy parser" bug: parameters used late in query must be captured early
-- This CTE MUST be first in the WITH clause or @SelectedView won't be recognized
InputVar AS (
    SELECT @SelectedView AS SelectedView
),

-- [STEP 1]: Generate Complete Date Range using Numbers CTE
-- Avoids recursion limit issues with large date ranges
-- Creates 10,000 possible row numbers (10^4) for flexibility
Numbers AS (
    SELECT 0 AS N
    UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
),
AllNumbers AS (
    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)) - 1 AS N
    FROM Numbers n1
    CROSS JOIN Numbers n2
    CROSS JOIN Numbers n3
    CROSS JOIN Numbers n4
),
DateList AS (
    SELECT DATEADD(DAY, N, @StartDate) AS ReportDate
    FROM AllNumbers
    WHERE DATEADD(DAY, N, @StartDate) <= @EndDate
),


-- [STEP 2]: Define Day Part Buckets
-- Hardcoded definitions to match business rules
-- SortOrder ensures Total row appears first (0), then parts in time sequence
DayPartDefs AS (
    SELECT 'Overnight (00-05)' AS DayPartLabel, 1 AS SortOrder
    UNION ALL
    SELECT 'Breakfast (05-11)', 2
    UNION ALL
    SELECT 'Day (11-17)', 3
    UNION ALL
    SELECT 'Night (17-24)', 4
),

-- [STEP 2.5]: Parse Site IDs from Comma-Separated String
-- OutSystems passes pre-filtered list of Site IDs as TEXT (tenant filtering already done)
-- Using Numbers table approach to split comma-separated string (SQL Server 2014+ compatible)
SiteIdNumbers AS (
    -- Generate numbers 1 to 1000 (supports up to 1000 comma-separated IDs)
    SELECT TOP 1000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N
    FROM AllNumbers
),

SplitSiteIds AS (
    SELECT
        CAST(LTRIM(RTRIM(SUBSTRING(
            @SiteIds,
            N,
            CASE
                WHEN CHARINDEX(',', @SiteIds, N) > 0 THEN CHARINDEX(',', @SiteIds, N) - N
                ELSE LEN(@SiteIds)
            END
        ))) AS BIGINT) AS SiteId
    FROM SiteIdNumbers
    WHERE N <= LEN(@SiteIds)
      AND SUBSTRING(',' + @SiteIds, N, 1) = ','
),

-- Join split IDs to Site table to get names
SiteList AS (
    SELECT DISTINCT
        split.SiteId,
        ISNULL(s.DisplayName, s.Name) AS SiteName
    FROM SplitSiteIds split
    INNER JOIN {Site} s ON s.Id = split.SiteId
),

-- [STEP 3]: Build Master Scaffold (Date x DayPart x Site Grid)
-- Cross join guarantees every date/daypart/site combination exists
-- Prevents "missing row" errors in the UI grid
Scaffold AS (
    SELECT
        d.ReportDate,
        p.DayPartLabel,
        p.SortOrder,
        site.SiteId,
        site.SiteName
    FROM DateList d
    CROSS JOIN DayPartDefs p
    CROSS JOIN SiteList site
),

-- [STEP 4a]: CURRENT YEAR DATA ONLY
-- Fetches CY data independently (no mixed CASE logic with PY)
-- Filtered by SiteList (pre-filtered by OutSystems tenant logic)
-- DateTime converted to NZ timezone (UTC+12/+13 depending on DST)
CY_RawData AS (
    SELECT
        sf.SiteId,
        CAST(CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time') AS DATE) AS ReportDate,
        -- [DAY PART BUCKETING]
        -- DATEPART(HOUR, ...) extracts 0-23 in NZ timezone
        -- CASE statement buckets into 4 ranges
        CASE
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 0  AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 5  THEN 'Overnight (00-05)'
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 5  AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 11 THEN 'Breakfast (05-11)'
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 11 AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 17 THEN 'Day (11-17)'
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 17 THEN 'Night (17-24)'
        END AS DayPartLabel,
        SUM(sf.NetAmount) AS CY_NetAmount,
        SUM(sf.TransactionCount) AS CY_TransactionCount
    FROM {SalesFact} sf
    WHERE sf.SiteId IN (SELECT SiteId FROM SiteList)
      AND sf.CalendarDate BETWEEN @StartDate AND @EndDate
      -- [EARLY FILTERING FOR INDEX PUSHDOWN]
      -- Critical filters applied FIRST so SQL Server uses optimal index
      AND sf.DatePeriodDimensionId = 15
      AND sf.ProductMenuId IS NULL
      AND sf.ProductSaleTypeId = 1
      AND sf.TenderTypeId IS NULL
      AND sf.OperationId IS NULL
      AND sf.OperationKindId IS NULL
      AND sf.SWCCashDrawerId IS NULL
      AND sf.SaleTypeId IS NULL
      AND sf.Pod = ''
      AND ISNULL(sf.PosId,0)=0
    GROUP BY
        sf.SiteId,
        CAST(CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time') AS DATE),
        CASE
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 0  AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 5  THEN 'Overnight (00-05)'
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 5  AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 11 THEN 'Breakfast (05-11)'
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 11 AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 17 THEN 'Day (11-17)'
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 17 THEN 'Night (17-24)'
        END
),

-- [STEP 4b]: PREVIOUS YEAR DATA (shifted forward by 364 days)
-- Fetches PY data completely independently
-- Shifted by 364 days (52 weeks) to align day-of-week (e.g., Monday to Monday)
-- Filtered by SiteList (pre-filtered by OutSystems tenant logic)
-- DateTime converted to NZ timezone
PY_RawData AS (
    SELECT
        sf.SiteId,
        DATEADD(DAY, 364, CAST(CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time') AS DATE)) AS ReportDate,
        CASE
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 0  AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 5  THEN 'Overnight (00-05)'
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 5  AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 11 THEN 'Breakfast (05-11)'
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 11 AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 17 THEN 'Day (11-17)'
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 17 THEN 'Night (17-24)'
        END AS DayPartLabel,
        SUM(sf.NetAmount) AS PY_NetAmount,
        SUM(sf.TransactionCount) AS PY_TransactionCount
    FROM {SalesFact} sf
    WHERE sf.SiteId IN (SELECT SiteId FROM SiteList)
      AND sf.CalendarDate BETWEEN DATEADD(DAY, -364, @StartDate) AND DATEADD(DAY, -364, @EndDate)
      -- [EARLY FILTERING FOR INDEX PUSHDOWN]
      AND sf.DatePeriodDimensionId = 15
      AND sf.ProductMenuId IS NULL
      AND sf.ProductSaleTypeId = 1
      AND sf.TenderTypeId IS NULL
      AND sf.OperationId IS NULL
      AND sf.OperationKindId IS NULL
      AND sf.SWCCashDrawerId IS NULL
      AND sf.SaleTypeId IS NULL
      AND sf.Pod = ''
      AND ISNULL(sf.PosId,0)=0
    GROUP BY
        sf.SiteId,
        DATEADD(DAY, 364, CAST(CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time') AS DATE)),
        CASE
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 0  AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 5  THEN 'Overnight (00-05)'
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 5  AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 11 THEN 'Breakfast (05-11)'
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 11 AND DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) < 17 THEN 'Day (11-17)'
            WHEN DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) >= 17 THEN 'Night (17-24)'
        END
),

-- [STEP 5]: Merge Scaffold with CY and PY Data
-- Left joins ensure every date/daypart/site combination exists with 0 if no sales
-- ISNULL converts NULL to 0.00 for empty cells
CleanedData AS (
    SELECT
        s.ReportDate,
        s.SiteId,
        s.SiteName,
        s.DayPartLabel,
        s.SortOrder,
        ISNULL(cy.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(cy.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(py.PY_NetAmount, 0) AS PY_NetAmount,
        ISNULL(py.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM Scaffold s
    LEFT JOIN CY_RawData cy ON s.ReportDate = cy.ReportDate AND s.DayPartLabel = cy.DayPartLabel AND s.SiteId = cy.SiteId
    LEFT JOIN PY_RawData py ON s.ReportDate = py.ReportDate AND s.DayPartLabel = py.DayPartLabel AND s.SiteId = py.SiteId
),

-- [STEP 6]: Calculate Daily Totals (00-24) per Site
-- Sums all day parts for each date and site to show full-day totals
-- This row should mathematically equal the sum of all 4 day parts per site
TotalData AS (
    SELECT
        ReportDate,
        SiteId,
        SiteName,
        'Total (00-24)' AS DayPartLabel,
        0 AS SortOrder,  -- 0 ensures Total appears first in sort
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM CleanedData
    GROUP BY ReportDate, SiteId, SiteName
),

-- [STEP 7]: Combine Individual Day Parts with Total Row
CombinedSet AS (
    SELECT * FROM CleanedData
    UNION ALL
    SELECT * FROM TotalData
)

-- [STEP 8]: Calculate Final Metrics & Project Output
SELECT
    ReportDate AS Date,
    SiteName,
    DayPartLabel,

    -- [CALC 1: Main Value]
    -- Dynamically selects metric based on @SelectedView parameter
    -- Using InputVar CTE to avoid OutSystems "lazy parser" bug
    CASE (SELECT SelectedView FROM InputVar)
        WHEN 'D' THEN CY_NetAmount              -- Dollar Amount ($)
        WHEN 'G' THEN CAST(CY_TransactionCount AS DECIMAL(18,2))  -- Guest Count (#)
        WHEN 'A' THEN CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END  -- Average Check ($)
        ELSE 0
    END AS Value,

    -- [CALC 2: Percent of Daily Total (per Site)]
    -- Shows what % of that site's daily total this day part represents
    -- Returns 0 for Average view (statistically invalid)
    -- Using InputVar CTE to avoid OutSystems "lazy parser" bug
    CASE
        WHEN (SELECT SelectedView FROM InputVar) = 'A' THEN 0
        WHEN (SELECT SelectedView FROM InputVar) = 'D' THEN
             CASE
                WHEN MAX(CASE WHEN SortOrder = 0 THEN CY_NetAmount ELSE 0 END) OVER (PARTITION BY ReportDate, SiteId) = 0 THEN 0
                ELSE CY_NetAmount * 100.0 / NULLIF(MAX(CASE WHEN SortOrder = 0 THEN CY_NetAmount ELSE 0 END) OVER (PARTITION BY ReportDate, SiteId), 0)
             END
        WHEN (SELECT SelectedView FROM InputVar) = 'G' THEN
             CASE
                WHEN MAX(CASE WHEN SortOrder = 0 THEN CY_TransactionCount ELSE 0 END) OVER (PARTITION BY ReportDate, SiteId) = 0 THEN 0
                ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / NULLIF(MAX(CASE WHEN SortOrder = 0 THEN CY_TransactionCount ELSE 0 END) OVER (PARTITION BY ReportDate, SiteId), 0)
             END
        ELSE 0
    END AS PercentTotal,

    -- [CALC 3: Year-over-Year Growth %]
    -- Formula: (CY - PY) / PY * 100
    -- Handles division by zero; returns 0 if no prior year data exists
    -- Using InputVar CTE to avoid OutSystems "lazy parser" bug
    CASE (SELECT SelectedView FROM InputVar)
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

FROM CombinedSet
ORDER BY
    Date ASC,
    SiteName ASC,
    SortOrder ASC;
