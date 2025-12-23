/*
   ===================================================================================
   QUERY: PRODUCT SALES BY POS TYPE - MULTI-SITE v2.1.0 (Story 3572)
   ===================================================================================

   PURPOSE:
   Daily sales breakdown by Pod (Counter, Drive-Thru, Kiosk, Delivery) with YoY comparison.
   
   ⚠️ OUTSYSTEMS SETUP:
   - SiteIds (Text)      → Expand Inline = YES
   - StartDate (Date)    → Expand Inline = No
   - EndDate (Date)      → Expand Inline = No
   - SelectedView (Text) → Expand Inline = No

   CHANGE FROM ORIGINAL:
   - @SiteId BIGINT → @SiteIds in WHERE SiteId IN (@SiteIds)
   - Added SiteList CTE for site names
   - Added SiteName to output
   - Updated partitions to include SiteId
   - Added InputVar CTE for OutSystems lazy parser fix
   
   NO OTHER FILTERS CHANGED - matches original exactly!
   ===================================================================================
*/

WITH

-- InputVar CTE (OutSystems lazy parser fix)
InputVar AS (
    SELECT @SelectedView AS SelectedView, @EndDate AS EndDate
),

-- Get Site Names
SiteList AS (
    SELECT s.Id AS SiteId, ISNULL(s.DisplayName, s.Name) AS SiteName
    FROM {Site} s
    WHERE s.Id IN (@SiteIds)
),

-- [STEP 1]: Generate Date Range
DateList AS (
    SELECT @StartDate AS ReportDate
    UNION ALL
    SELECT DATEADD(DAY, 1, ReportDate)
    FROM DateList
    WHERE ReportDate < @EndDate
),

-- [STEP 2]: Fetch Data using UNION ALL (Matches Granular Test Logic)
RawDataPoints AS (
    -- Query A: Current Year
    SELECT
        SiteId,
        CalendarDate AS ReportDate,
        [DateTime],
        Pod,
        PosId,
        TransactionCount AS CY_TransactionCount,
        NetAmount AS CY_NetAmount,
        0 AS PY_TransactionCount,
        0 AS PY_NetAmount
    FROM {SalesFact}
    WHERE SiteId IN (@SiteIds)
      AND CalendarDate BETWEEN @StartDate AND @EndDate
      -- Filters match 'test-granular-view.sql' exactly
      AND DatePeriodDimensionId = 15
      AND ProductSaleTypeId = 1
      AND ProductMenuId IS NULL
      AND TenderTypeId IS NULL
      AND OperationId IS NULL
      AND OperationKindId IS NULL
      AND SWCCashDrawerId IS NULL
      AND SaleTypeId IS NULL
      AND PosId IS NOT NULL AND PosId <> 0 -- Exclude Summary Rows
      AND Pod IS NOT NULL AND Pod <> ''

    UNION ALL

    -- Query B: Previous Year
    SELECT
        SiteId,
        DATEADD(DAY, 364, CalendarDate) AS ReportDate,
        [DateTime],
        Pod,
        PosId,
        0, 0,
        TransactionCount,
        NetAmount
    FROM {SalesFact}
    WHERE SiteId IN (@SiteIds)
      AND CalendarDate BETWEEN DATEADD(DAY, -364, @StartDate) AND DATEADD(DAY, -364, @EndDate)
      -- Filters match 'test-granular-view.sql' exactly
      AND DatePeriodDimensionId = 15
      AND ProductSaleTypeId = 1
      AND ProductMenuId IS NULL
      AND TenderTypeId IS NULL
      AND OperationId IS NULL
      AND OperationKindId IS NULL
      AND SWCCashDrawerId IS NULL
      AND SaleTypeId IS NULL
      AND PosId IS NOT NULL AND PosId <> 0 -- Exclude Summary Rows
      AND Pod IS NOT NULL AND Pod <> ''
),

-- [STEP 3]: Dedup Raw Data (Handle Duplicate Headers)
-- Groups by unique transaction keys and takes MAX() to avoid double counting
DedupedData AS (
    SELECT
        SiteId,
        ReportDate,
        Pod,
        MAX(CY_NetAmount) AS CY_NetAmount,
        MAX(CY_TransactionCount) AS CY_TransactionCount,
        MAX(PY_NetAmount) AS PY_NetAmount,
        MAX(PY_TransactionCount) AS PY_TransactionCount
    FROM RawDataPoints
    GROUP BY SiteId, ReportDate, Pod, PosId, [DateTime]
),

-- [STEP 4]: Aggregate
AggregatedData AS (
    SELECT
        SiteId,
        ReportDate,
        Pod,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM DedupedData
    GROUP BY SiteId, ReportDate, Pod
),

-- [STEP 4]: Active Pods
ActivePods AS (
    SELECT DISTINCT SiteId, Pod
    FROM AggregatedData
    WHERE CY_TransactionCount > 0 OR CY_NetAmount <> 0
),

-- [STEP 5]: Build Grid
GridData AS (
    SELECT
        s.SiteId,
        s.SiteName,
        d.ReportDate,
        p.Pod,
        ISNULL(a.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(a.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(a.PY_NetAmount, 0) AS PY_NetAmount,
        ISNULL(a.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM SiteList s
    CROSS JOIN DateList d
    CROSS JOIN (SELECT DISTINCT Pod FROM ActivePods) p
    LEFT JOIN AggregatedData a 
        ON s.SiteId = a.SiteId 
        AND d.ReportDate = a.ReportDate 
        AND p.Pod = a.Pod
),

-- [STEP 6]: Totals & Sorting (Per-Day Per-Site)
FinalSet AS (
    SELECT
        SiteId, SiteName, ReportDate, Pod,
        CY_NetAmount, CY_TransactionCount, PY_NetAmount, PY_TransactionCount,
        SUM(CY_NetAmount) OVER(PARTITION BY SiteId, ReportDate) AS DailyTotal_Net,
        SUM(CY_TransactionCount) OVER(PARTITION BY SiteId, ReportDate) AS DailyTotal_Txn,
        ROW_NUMBER() OVER (PARTITION BY SiteId, ReportDate ORDER BY Pod) AS SortOrder
    FROM GridData

    UNION ALL

    SELECT
        SiteId, SiteName, ReportDate, 'Total' AS Pod,
        SUM(CY_NetAmount), SUM(CY_TransactionCount), SUM(PY_NetAmount), SUM(PY_TransactionCount),
        SUM(CY_NetAmount), SUM(CY_TransactionCount),
        0 AS SortOrder
    FROM GridData
    GROUP BY SiteId, SiteName, ReportDate
),

-- [STORY 3572]: Grand Total rows - aggregates across ENTIRE filtered dataset
-- Uses GROUPING SETS for single-scan optimization
-- Returns N+1 rows: Total + N active Pods (all aggregated across date range)
GrandTotal AS (
    SELECT 
        NULL AS SiteId,
        'Grand Totals' AS SiteName,
        NULL AS ReportDate,
        CASE 
            WHEN GROUPING(Pod) = 1 THEN 'Total'
            ELSE Pod
        END AS Pod,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount,
        -- DailyTotal must be OVERALL total, not per-pod (so % calculation works)
        SUM(SUM(CY_NetAmount)) OVER() AS DailyTotal_Net,
        SUM(SUM(CY_TransactionCount)) OVER() AS DailyTotal_Txn,
        CASE 
            WHEN GROUPING(Pod) = 1 THEN -99       -- Grand Total first
            ELSE -50 + ROW_NUMBER() OVER (ORDER BY Pod)  -- Then pods in order
        END AS SortOrder
    FROM GridData
    GROUP BY GROUPING SETS (
        (),    -- Overall Total
        (Pod)  -- Per-Pod Totals
    )
),

CombinedSet AS (
    SELECT * FROM GrandTotal          -- Grand totals FIRST
    UNION ALL SELECT * FROM FinalSet
)

-- [STEP 7]: Final Output
SELECT
    ReportDate AS Date,
    SiteId,
    SiteName,
    Pod,

    CASE (SELECT SelectedView FROM InputVar)
        WHEN 'D' THEN CY_NetAmount
        WHEN 'G' THEN CAST(CY_TransactionCount AS DECIMAL(18,2))
        WHEN 'A' THEN CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END
        ELSE 0
    END AS Value,

    CASE
        WHEN (SELECT SelectedView FROM InputVar) = 'A' THEN 0
        -- Grand Total 'Total' row (SortOrder = -99) shows 100%
        WHEN SortOrder = -99 THEN 100.0
        -- Grand Total pod rows show % of grand total
        WHEN SortOrder < 0 AND (SELECT SelectedView FROM InputVar) = 'D' THEN
            CASE WHEN DailyTotal_Net = 0 THEN 0 ELSE CY_NetAmount * 100.0 / DailyTotal_Net END
        WHEN SortOrder < 0 AND (SELECT SelectedView FROM InputVar) = 'G' THEN
            CASE WHEN DailyTotal_Txn = 0 THEN 0 ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / DailyTotal_Txn END
        -- Daily rows - % of daily total
        WHEN (SELECT SelectedView FROM InputVar) = 'D' THEN
            CASE WHEN DailyTotal_Net = 0 THEN 0 ELSE CY_NetAmount * 100.0 / DailyTotal_Net END
        WHEN (SELECT SelectedView FROM InputVar) = 'G' THEN
            CASE WHEN DailyTotal_Txn = 0 THEN 0 ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / DailyTotal_Txn END
        ELSE 0
    END AS PercentTotal,

    CASE (SELECT SelectedView FROM InputVar)
        WHEN 'D' THEN
            CASE WHEN PY_NetAmount = 0 THEN 0 ELSE (CY_NetAmount - PY_NetAmount) * 100.0 / PY_NetAmount END
        WHEN 'G' THEN
            CASE WHEN PY_TransactionCount = 0 THEN 0 ELSE (CY_TransactionCount - PY_TransactionCount) * 100.0 / PY_TransactionCount END
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
WHERE ReportDate IS NULL                     -- Grand totals (no date filter)
   OR (ReportDate <= (SELECT EndDate FROM InputVar)
       AND ReportDate < CAST(SYSDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time' AS DATE))
ORDER BY 
    CASE WHEN SortOrder < 0 THEN 0 ELSE 1 END,  -- Grand Totals first
    SortOrder ASC,
    Date ASC, SiteName ASC
OPTION (MAXRECURSION 1000, RECOMPILE)
