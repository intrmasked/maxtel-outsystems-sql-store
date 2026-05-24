-- =============================================
-- TEMPLATE: Date Range + Year-over-Year (YoY) Query
-- Purpose: Proven pattern for CY vs PY comparison queries
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Performance: 30-day range ~1s (down from 16s with separate CTEs)
--
-- WHY THIS PATTERN WORKS:
--   1. UNION ALL forces parallel index seeks (16x faster than separate CTEs)
--   2. Pre-aggregation reduces data volume before building scaffold
--   3. ActivePods derived from aggregated data (zero extra DB hits)
--   4. Window functions calculate totals without extra joins
--   5. RECOMPILE gives optimal plan for varying date ranges
--
-- STEPS:
--   1. Generate date range (recursive CTE)
--   2. Fetch CY + PY via UNION ALL
--   3. Aggregate combined data
--   4. Derive active dimensions from aggregated data
--   5. Build scaffold (dates x dimensions)
--   6. LEFT JOIN aggregated data to scaffold
--   7. Window functions for totals
--   8. Final SELECT with SelectedView logic
-- =============================================

-- Parameters (replace with OutSystems Input Parameters in production)
DECLARE @SiteId BIGINT = 3187;
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';
DECLARE @SelectedView VARCHAR(1) = 'D';

WITH

-- [STEP 1]: Generate Date Range (if needed)
DateList AS (
    SELECT @StartDate AS ReportDate
    UNION ALL
    SELECT DATEADD(DAY, 1, ReportDate)
    FROM DateList
    WHERE ReportDate < @EndDate
),

-- [STEP 2]: Fetch CY + PY Data using UNION ALL (CRITICAL FOR PERFORMANCE!)
RawDataPoints AS (
    -- Query A: Current Year (Direct Index Seek)
    SELECT
        CalendarDate AS ReportDate,
        Pod,
        NetAmount AS CY_NetAmount,
        TransactionCount AS CY_TransactionCount,
        0 AS PY_NetAmount,
        0 AS PY_TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
      AND CalendarDate BETWEEN @StartDate AND @EndDate
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

    -- Query B: Previous Year (Direct Index Seek)
    SELECT
        DATEADD(DAY, 364, CalendarDate) AS ReportDate,
        Pod,
        0, 0, -- CY Cols are 0
        NetAmount,
        TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
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

-- [STEP 3]: Aggregate Combined Data (BEFORE building scaffold!)
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

-- [STEP 4]: Identify Active Pods (Derived from aggregated data)
ActivePods AS (
    SELECT DISTINCT Pod
    FROM AggregatedData
    WHERE CY_TransactionCount > 0 OR CY_NetAmount <> 0
),

-- [STEP 5]: Build Scaffold (Date Range x Active Pods)
Scaffold AS (
    SELECT d.ReportDate, p.Pod
    FROM DateList d
    CROSS JOIN ActivePods p
),

-- [STEP 6]: Merge Scaffold with Aggregated Data
GridData AS (
    SELECT
        s.ReportDate,
        s.Pod,
        ISNULL(a.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(a.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(a.PY_NetAmount, 0) AS PY_NetAmount,
        ISNULL(a.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM Scaffold s
    LEFT JOIN AggregatedData a ON s.ReportDate = a.ReportDate AND s.Pod = a.Pod
),

-- [STEP 7]: Calculate Final Metrics with Window Functions
FinalSet AS (
    -- Individual Rows
    SELECT
        ReportDate,
        Pod,
        CY_NetAmount,
        CY_TransactionCount,
        PY_NetAmount,
        PY_TransactionCount,
        SUM(CY_NetAmount) OVER(PARTITION BY ReportDate) as DailyTotal_Net,
        SUM(CY_TransactionCount) OVER(PARTITION BY ReportDate) as DailyTotal_Txn,
        ROW_NUMBER() OVER (PARTITION BY ReportDate ORDER BY Pod) AS SortOrder
    FROM GridData

    UNION ALL

    -- Total Row
    SELECT
        ReportDate,
        'Total' AS Pod,
        SUM(CY_NetAmount),
        SUM(CY_TransactionCount),
        SUM(PY_NetAmount),
        SUM(PY_TransactionCount),
        SUM(CY_NetAmount),
        SUM(CY_TransactionCount),
        0 AS SortOrder
    FROM GridData
    GROUP BY ReportDate
)

-- [STEP 8]: Final Output with Calculations
SELECT
    ReportDate AS Date,
    Pod,

    -- Value based on SelectedView
    CASE @SelectedView
        WHEN 'D' THEN CY_NetAmount
        WHEN 'G' THEN CAST(CY_TransactionCount AS DECIMAL(18,2))
        WHEN 'A' THEN CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END
        ELSE 0
    END AS Value,

    -- Percent Total
    CASE
        WHEN @SelectedView = 'A' THEN 0
        WHEN @SelectedView = 'D' THEN
            CASE WHEN DailyTotal_Net = 0 THEN 0 ELSE CY_NetAmount * 100.0 / DailyTotal_Net END
        WHEN @SelectedView = 'G' THEN
            CASE WHEN DailyTotal_Txn = 0 THEN 0 ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / DailyTotal_Txn END
        ELSE 0
    END AS PercentTotal,

    -- Year-over-Year Growth %
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
ORDER BY Date ASC, SortOrder ASC
OPTION (MAXRECURSION 1000, RECOMPILE);  -- CRITICAL for date range queries
