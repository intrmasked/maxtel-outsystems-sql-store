-- =============================================
-- Query: Product Sales By POS Type (Date Range)
-- Purpose: Daily sales breakdown by Pod with YoY comparison
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2025-12-09
-- Updated: 2025-12-10 - Performance optimization (16s → 1s for 30 days)
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';
DECLARE @SelectedView VARCHAR(1) = 'D';  -- 'D' = Sales, 'G' = Guest Count, 'A' = Average Check

WITH

-- [STEP 1]: Generate Date Range (Standard Recursive)
DateList AS (
    SELECT @StartDate AS ReportDate
    UNION ALL
    SELECT DATEADD(DAY, 1, ReportDate)
    FROM DateList
    WHERE ReportDate < @EndDate
),

-- [STEP 2]: Fetch Data using UNION ALL to force INDEX SEEKS
-- We split the query in two. SQL Server runs these in parallel very quickly.
RawDataPoints AS (
    -- Query A: Current Year Data (Direct Index Seek)
    SELECT
        CalendarDate AS ReportDate,
        Pod,
        NetAmount AS CY_NetAmount,
        TransactionCount AS CY_TransactionCount,
        0 AS PY_NetAmount,
        0 AS PY_TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
      AND CalendarDate BETWEEN @StartDate AND @EndDate -- Direct Index Hit
      AND DatePeriodDimensionId = 15
      AND ProductSaleTypeId = 1
      AND ProductMenuId IS NULL
      AND TenderTypeId IS NULL
      AND OperationId IS NULL
      AND OperationKindId IS NULL
      AND SWCCashDrawerId IS NULL
      AND SaleTypeId IS NULL
      AND PosId IS NOT NULL
      AND Pod IS NOT NULL AND Pod <> ''

    UNION ALL

    -- Query B: Previous Year Data (Direct Index Seek)
    SELECT
        DATEADD(DAY, 364, CalendarDate) AS ReportDate, -- Shift Date Forward
        Pod,
        0, 0, -- CY Cols are 0
        NetAmount,
        TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
      -- We calculate the PY range directly in the WHERE clause
      -- SQL Server optimizes functions on parameters (Constants) efficiently
      AND CalendarDate BETWEEN DATEADD(DAY, -364, @StartDate) AND DATEADD(DAY, -364, @EndDate)
      AND DatePeriodDimensionId = 15
      AND ProductSaleTypeId = 1
      AND ProductMenuId IS NULL
      AND TenderTypeId IS NULL
      AND OperationId IS NULL
      AND OperationKindId IS NULL
      AND SWCCashDrawerId IS NULL
      AND SaleTypeId IS NULL
      AND PosId IS NOT NULL
      AND Pod IS NOT NULL AND Pod <> ''
),

-- [STEP 3]: Aggregate the Combined Points
AggregatedData AS (
    SELECT
        ReportDate,
        Pod,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM RawDataPoints
    GROUP BY ReportDate, Pod
),

-- [STEP 4]: Identify Active Pods (Only those with CY activity)
ActivePods AS (
    SELECT DISTINCT Pod
    FROM AggregatedData
    WHERE CY_TransactionCount > 0 OR CY_NetAmount <> 0
),

-- [STEP 5]: Build Grid (Dates x Active Pods)
GridData AS (
    SELECT
        d.ReportDate,
        p.Pod,
        ISNULL(a.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(a.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(a.PY_NetAmount, 0) AS PY_NetAmount,
        ISNULL(a.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM DateList d
    CROSS JOIN ActivePods p
    LEFT JOIN AggregatedData a ON d.ReportDate = a.ReportDate AND p.Pod = a.Pod
),

-- [STEP 6]: Calculate Totals & Sorting
FinalSet AS (
    -- Individual Pods
    SELECT
        ReportDate,
        Pod,
        CY_NetAmount,
        CY_TransactionCount,
        PY_NetAmount,
        PY_TransactionCount,
        -- Window Functions for Daily Totals
        SUM(CY_NetAmount) OVER(PARTITION BY ReportDate) as DailyTotal_Net,
        SUM(CY_TransactionCount) OVER(PARTITION BY ReportDate) as DailyTotal_Txn,
        ROW_NUMBER() OVER (PARTITION BY ReportDate ORDER BY Pod) AS SortOrder
    FROM GridData

    UNION ALL

    -- Total Row (Aggregated from GridData)
    SELECT
        ReportDate,
        'Total' AS Pod,
        SUM(CY_NetAmount),
        SUM(CY_TransactionCount),
        SUM(PY_NetAmount),
        SUM(PY_TransactionCount),
        SUM(CY_NetAmount), -- Total of Total is itself
        SUM(CY_TransactionCount),
        0 AS SortOrder
    FROM GridData
    GROUP BY ReportDate
)

-- [STEP 7]: Final Calculation
SELECT
    ReportDate AS Date,
    Pod,

    -- VALUE
    CASE @SelectedView
        WHEN 'D' THEN CY_NetAmount
        WHEN 'G' THEN CAST(CY_TransactionCount AS DECIMAL(18,2))
        WHEN 'A' THEN CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END
        ELSE 0
    END AS Value,

    -- PERCENT TOTAL
    CASE
        WHEN @SelectedView = 'A' THEN 0
        WHEN @SelectedView = 'D' THEN
            CASE WHEN DailyTotal_Net = 0 THEN 0 ELSE CY_NetAmount * 100.0 / DailyTotal_Net END
        WHEN @SelectedView = 'G' THEN
            CASE WHEN DailyTotal_Txn = 0 THEN 0 ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / DailyTotal_Txn END
        ELSE 0
    END AS PercentTotal,

    -- PERCENT INC (YoY)
    CASE @SelectedView
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

FROM FinalSet
WHERE ReportDate <= @EndDate
  -- Cap future dates to today (NZ Time)
  AND ReportDate < CAST(SYSDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time' AS DATE)
ORDER BY
    Date ASC,
    SortOrder ASC
OPTION (MAXRECURSION 1000, RECOMPILE);
