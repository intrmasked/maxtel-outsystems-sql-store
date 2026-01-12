/*
   ===================================================================================
   TEST QUERY: PRODUCT SALES BY DAY PART - v8.1.0 (Optimized)
   ===================================================================================

   PRINCIPLES (Copied from fast POS Query):
   1. ATOMIC DATA: Filter for `PosId <> 0` and `Pod <> ''` (Real transactions).
      - Rationale: Time-of-day analysis requires atomic transaction timestamps.
   2. FAST FETCH: `UNION ALL` for separate CY/PY Index Seeks.
   3. PRE-AGGREGATION: Group by Integer Keys (Site, Date, Hour) immediately.
   4. ZERO-COST TOTALS: Handle all rollups in memory loops or Grouping Sets on tiny data.

   Day Parts:
   - Overnight (00-05)
   - Breakfast (05-11)
   - Day (11-17)
   - Night (17-24)

   OPTIMIZATIONS (v8.1.0):
   - ✅ Eliminated correlated SiteName subquery via LEFT JOIN
   - ✅ Eliminated repeated InputVar subqueries via CROSS JOIN
   - ✅ Early date filtering in HourlyAgg CTE
   - Expected Performance Gain: 20-40% for multi-site queries
   ===================================================================================
*/

DECLARE @SiteIds NVARCHAR(MAX) = '3188,3189,3190';
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-31';
DECLARE @SelectedView VARCHAR(1) = 'D';

WITH

InputVar AS (
    SELECT @SelectedView AS SelectedView
),

SiteList AS (
    SELECT s.Id AS SiteId, ISNULL(s.DisplayName, s.Name) AS SiteName
    FROM {Site} s
    WHERE s.Id IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
),

-- [STEP 1] Raw Fetch & Hour Extraction (Atomic Rows)
RawHours AS (
    -- CY Data
    SELECT
        sf.SiteId,
        sf.CalendarDate AS ReportDate,
        -- Fast Integer Hour Extraction
        DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS SaleHour,
        sf.NetAmount AS CY_NetAmount,
        sf.TransactionCount AS CY_TransactionCount,
        0 AS PY_NetAmount,
        0 AS PY_TransactionCount
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
      -- [ALIGNMENT] Match POS Query Filters
      AND sf.PosId IS NOT NULL AND sf.PosId <> 0
      AND sf.Pod IS NOT NULL AND sf.Pod <> ''

    UNION ALL

    -- PY Data
    SELECT
        sf.SiteId,
        DATEADD(DAY, 364, sf.CalendarDate) AS ReportDate,
        DATEPART(HOUR, CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS SaleHour,
        0, 0,
        sf.NetAmount,
        sf.TransactionCount
    FROM {SalesFact} sf
    WHERE sf.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
      AND sf.CalendarDate BETWEEN DATEADD(DAY, -364, @StartDate) AND DATEADD(DAY, -364, @EndDate)
      AND sf.DatePeriodDimensionId = 15
      AND sf.ProductSaleTypeId = 1
      AND sf.ProductMenuId IS NULL
      AND sf.TenderTypeId IS NULL
      AND sf.OperationId IS NULL
      AND sf.OperationKindId IS NULL
      AND sf.SWCCashDrawerId IS NULL
      AND sf.SaleTypeId IS NULL
      -- [ALIGNMENT] Match POS Query Filters
      AND sf.PosId IS NOT NULL AND sf.PosId <> 0
      AND sf.Pod IS NOT NULL AND sf.Pod <> ''
),

-- [STEP 2] Pre-Aggregate by Integer Keys (Shrink Data ASAP)
HourlyAgg AS (
    SELECT
        SiteId,
        ReportDate,
        SaleHour,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM RawHours
    -- ✅ OPTIMIZATION: Filter early to reduce processing
    WHERE ReportDate <= @EndDate
    GROUP BY SiteId, ReportDate, SaleHour
),

-- [STEP 3] Labeling & Weighting (on tiny dataset)
LabeledAgg AS (
    SELECT
        SiteId, 
        ReportDate,
        CASE 
            WHEN SaleHour BETWEEN 0 AND 4 THEN 'Overnight (00-05)'
            WHEN SaleHour BETWEEN 5 AND 10 THEN 'Breakfast (05-11)'
            WHEN SaleHour BETWEEN 11 AND 16 THEN 'Day (11-17)'
            ELSE 'Night (17-24)'
        END AS DayPartLabel,
        CASE 
            WHEN SaleHour BETWEEN 0 AND 4 THEN 1
            WHEN SaleHour BETWEEN 5 AND 10 THEN 2
            WHEN SaleHour BETWEEN 11 AND 16 THEN 3
            ELSE 4
        END AS PartSortWeight,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM HourlyAgg
    GROUP BY 
        SiteId, 
        ReportDate,
        CASE 
            WHEN SaleHour BETWEEN 0 AND 4 THEN 'Overnight (00-05)'
            WHEN SaleHour BETWEEN 5 AND 10 THEN 'Breakfast (05-11)'
            WHEN SaleHour BETWEEN 11 AND 16 THEN 'Day (11-17)'
            ELSE 'Night (17-24)'
        END,
        CASE 
            WHEN SaleHour BETWEEN 0 AND 4 THEN 1
            WHEN SaleHour BETWEEN 5 AND 10 THEN 2
            WHEN SaleHour BETWEEN 11 AND 16 THEN 3
            ELSE 4
        END
),

-- [STEP 4] Single Pass Grouping Sets (Totals)
AllRows AS (
    SELECT
        la.SiteId,
        la.ReportDate,
        iv.SelectedView,  -- ✅ OPTIMIZATION: Add SelectedView as column (eliminates subqueries later)

        CASE
            WHEN GROUPING(la.DayPartLabel) = 1 THEN 'Total (00-24)'
            ELSE la.DayPartLabel
        END AS DayPartLabel,

        CASE
            WHEN GROUPING(la.DayPartLabel) = 1 THEN 0
            ELSE MIN(la.PartSortWeight)
        END AS SortWeight,

        SUM(la.CY_NetAmount) AS CY_NetAmount,
        SUM(la.CY_TransactionCount) AS CY_TransactionCount,
        SUM(la.PY_NetAmount) AS PY_NetAmount,
        SUM(la.PY_TransactionCount) AS PY_TransactionCount,

        MAX(SUM(la.CY_NetAmount)) OVER(PARTITION BY la.SiteId, la.ReportDate) AS DailyTotal_Net,
        MAX(SUM(la.CY_TransactionCount)) OVER(PARTITION BY la.SiteId, la.ReportDate) AS DailyTotal_Txn,

        MAX(SUM(la.CY_NetAmount)) OVER() AS GrandTotal_Net,
        MAX(SUM(la.CY_TransactionCount)) OVER() AS GrandTotal_Txn,

        GROUPING(la.SiteId) AS IsGrandrow,
        GROUPING(la.ReportDate) AS IsDateTotalRow,
        GROUPING(la.DayPartLabel) AS IsDailyTotalRow

    FROM LabeledAgg la
    CROSS JOIN InputVar iv  -- ✅ OPTIMIZATION: Join once instead of subquery per row
    GROUP BY GROUPING SETS (
        (la.SiteId, la.ReportDate, la.DayPartLabel, iv.SelectedView),
        (la.SiteId, la.ReportDate, iv.SelectedView),
        (la.DayPartLabel, iv.SelectedView),
        (iv.SelectedView)
    )
),

-- ✅ OPTIMIZATION: Join SiteList once to eliminate correlated subquery
AllRowsWithSites AS (
    SELECT
        ar.*,
        CASE
            WHEN ar.IsGrandrow = 1 THEN 'Grand Totals'
            ELSE sl.SiteName
        END AS SiteName
    FROM AllRows ar
    LEFT JOIN SiteList sl ON ar.SiteId = sl.SiteId
)

-- Final Projection
SELECT
    ReportDate AS Date,
    SiteId,
    SiteName,  -- ✅ OPTIMIZATION: Direct column reference (no correlated subquery!)
    CASE
        WHEN IsGrandrow = 1 AND IsDateTotalRow = 1 AND DayPartLabel IS NULL THEN 'Total'
        ELSE DayPartLabel
    END AS DayPartLabel,

    -- VALUES (✅ Direct reference to SelectedView column)
    CASE SelectedView
        WHEN 'D' THEN CY_NetAmount
        WHEN 'G' THEN CAST(CY_TransactionCount AS DECIMAL(18,2))
        WHEN 'A' THEN CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END
        ELSE 0
    END AS Value,

    -- PERCENT TOTAL (✅ Direct reference to SelectedView column)
    CASE
        WHEN SelectedView = 'A' THEN 0
        -- Global Grand Total
        WHEN IsGrandrow = 1 AND DayPartLabel = 'Total (00-24)' THEN 100.0
        -- Grand Totals
        WHEN IsGrandrow = 1 THEN
             CASE SelectedView
                 WHEN 'D' THEN CASE WHEN GrandTotal_Net = 0 THEN 0 ELSE CY_NetAmount * 100.0 / GrandTotal_Net END
                 WHEN 'G' THEN CASE WHEN GrandTotal_Txn = 0 THEN 0 ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / GrandTotal_Txn END
             END
        -- Daily Totals & Details
        WHEN SelectedView = 'D' THEN
             CASE WHEN DailyTotal_Net = 0 THEN 0 ELSE CY_NetAmount * 100.0 / DailyTotal_Net END
        WHEN SelectedView = 'G' THEN
             CASE WHEN DailyTotal_Txn = 0 THEN 0 ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / DailyTotal_Txn END
        ELSE 0
    END AS PercentTotal,

    -- YOY INC (✅ Direct reference to SelectedView column)
    CASE SelectedView
        WHEN 'D' THEN CASE WHEN PY_NetAmount = 0 THEN 0 ELSE (CY_NetAmount - PY_NetAmount) * 100.0 / PY_NetAmount END
        WHEN 'G' THEN CASE WHEN PY_TransactionCount = 0 THEN 0 ELSE (CAST(CY_TransactionCount AS DECIMAL(18,2)) - PY_TransactionCount) * 100.0 / PY_TransactionCount END
        WHEN 'A' THEN CASE WHEN PY_TransactionCount = 0 OR CY_TransactionCount = 0 THEN 0
                           WHEN (PY_NetAmount / PY_TransactionCount) = 0 THEN 0
                           ELSE ((CY_NetAmount / CY_TransactionCount) - (PY_NetAmount / PY_TransactionCount)) * 100.0 / (PY_NetAmount / PY_TransactionCount) END
        ELSE 0
    END AS PercentInc,

    -- SORT ORDER (Matching POS Logic)
    CASE
        WHEN IsGrandrow = 1 THEN -50 + SortWeight
        WHEN IsDailyTotalRow = 1 THEN 0
        ELSE SortWeight
    END AS SortOrder

FROM AllRowsWithSites  -- ✅ OPTIMIZATION: Select from new CTE with pre-joined SiteName
WHERE IsGrandrow = 1 OR ReportDate <= @EndDate
ORDER BY
    CASE WHEN IsGrandrow = 1 THEN 0 ELSE 1 END,
    Date ASC,
    SiteName ASC,  -- ✅ Now efficient (pre-computed column, no subquery)
    SortOrder ASC
OPTION (RECOMPILE);
