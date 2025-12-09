-- =============================================
-- Query: Product Sales By POS Type (Date Range)
-- Purpose: Daily sales breakdown by Pod with YoY comparison
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2025-12-09
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';
DECLARE @SelectedView VARCHAR(1) = 'D';  -- 'D' = Sales, 'G' = Guest Count, 'A' = Average Check

WITH

-- [STEP 1]: Generate Complete Date Range
DateList AS (
    SELECT @StartDate AS ReportDate
    UNION ALL
    SELECT DATEADD(DAY, 1, ReportDate)
    FROM DateList
    WHERE ReportDate < @EndDate
),

-- [STEP 2]: CURRENT YEAR DATA ONLY
CY_RawData AS (
    SELECT
        CalendarDate AS ReportDate,
        Pod,
        SUM(NetAmount) AS CY_NetAmount,
        SUM(TransactionCount) AS CY_TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
      AND CalendarDate BETWEEN @StartDate AND @EndDate
      AND DatePeriodDimensionId = 15
      AND ProductMenuId IS NULL
      AND ProductSaleTypeId = 1
      AND TenderTypeId IS NULL
      AND OperationId IS NULL
      AND OperationKindId IS NULL
      AND SWCCashDrawerId IS NULL
      AND SaleTypeId IS NULL
      AND PosId IS NOT NULL
      AND Pod IS NOT NULL AND Pod <> ''
    GROUP BY CalendarDate, Pod
),

-- [STEP 3]: Get Active Pods from CY data (no extra DB hit)
ActivePods AS (
    SELECT DISTINCT Pod
    FROM CY_RawData
),

-- [STEP 4]: Build Master Scaffold from active pods
-- Cross join date range with actual pods in data
Scaffold AS (
    SELECT d.ReportDate, p.Pod
    FROM DateList d
    CROSS JOIN ActivePods p
),

-- [STEP 5]: PREVIOUS YEAR DATA (shifted forward by 364 days)
PY_RawData AS (
    SELECT
        DATEADD(DAY, 364, CalendarDate) AS ReportDate,
        Pod,
        SUM(NetAmount) AS PY_NetAmount,
        SUM(TransactionCount) AS PY_TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
      AND CalendarDate BETWEEN DATEADD(DAY, -364, @StartDate) AND DATEADD(DAY, -364, @EndDate)
      AND DatePeriodDimensionId = 15
      AND ProductMenuId IS NULL
      AND ProductSaleTypeId = 1
      AND TenderTypeId IS NULL
      AND OperationId IS NULL
      AND OperationKindId IS NULL
      AND SWCCashDrawerId IS NULL
      AND SaleTypeId IS NULL
      AND PosId IS NOT NULL
      AND Pod IS NOT NULL AND Pod <> ''
    GROUP BY DATEADD(DAY, 364, CalendarDate), Pod
),

-- [STEP 6]: Merge Scaffold with Raw Data
CleanedData AS (
    SELECT
        s.ReportDate,
        s.Pod,
        ISNULL(cy.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(cy.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(py.PY_NetAmount, 0) AS PY_NetAmount,
        ISNULL(py.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM Scaffold s
    LEFT JOIN CY_RawData cy ON s.ReportDate = cy.ReportDate AND s.Pod = cy.Pod
    LEFT JOIN PY_RawData py ON s.ReportDate = py.ReportDate AND s.Pod = py.Pod
),

-- [STEP 7]: Calculate Daily Totals Row
TotalData AS (
    SELECT
        ReportDate,
        'Total' AS Pod,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM CleanedData
    GROUP BY ReportDate
),

-- [STEP 8]: Combine Individual Pods with Total Row
-- Add SortOrder to match get-pods-by-date-range ordering
FinalSet AS (
    -- Total row (SortOrder = 0)
    SELECT
        ReportDate,
        Pod,
        CY_NetAmount,
        CY_TransactionCount,
        PY_NetAmount,
        PY_TransactionCount,
        0 AS SortOrder
    FROM TotalData

    UNION ALL

    -- Individual Pod rows (SortOrder = 1, 2, 3...)
    SELECT
        ReportDate,
        Pod,
        CY_NetAmount,
        CY_TransactionCount,
        PY_NetAmount,
        PY_TransactionCount,
        ROW_NUMBER() OVER (PARTITION BY ReportDate ORDER BY Pod) AS SortOrder
    FROM CleanedData
)

-- [STEP 9]: Calculate Final Metrics
SELECT
    ReportDate AS Date,
    Pod,

    -- [CALC 1: Main Value]
    CASE @SelectedView
        WHEN 'D' THEN CY_NetAmount
        WHEN 'G' THEN CAST(CY_TransactionCount AS DECIMAL(18,2))
        WHEN 'A' THEN CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END
        ELSE 0
    END AS Value,

    -- [CALC 2: Percent of Daily Total]
    CASE
        WHEN @SelectedView = 'A' THEN 0
        WHEN @SelectedView = 'D' THEN
            CASE
                WHEN MAX(CASE WHEN Pod = 'Total' THEN CY_NetAmount ELSE 0 END) OVER (PARTITION BY ReportDate) = 0 THEN 0
                ELSE CY_NetAmount * 100.0 / NULLIF(MAX(CASE WHEN Pod = 'Total' THEN CY_NetAmount ELSE 0 END) OVER (PARTITION BY ReportDate), 0)
            END
        WHEN @SelectedView = 'G' THEN
            CASE
                WHEN MAX(CASE WHEN Pod = 'Total' THEN CY_TransactionCount ELSE 0 END) OVER (PARTITION BY ReportDate) = 0 THEN 0
                ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / NULLIF(MAX(CASE WHEN Pod = 'Total' THEN CY_TransactionCount ELSE 0 END) OVER (PARTITION BY ReportDate), 0)
            END
        ELSE 0
    END AS PercentTotal,

    -- [CALC 3: Year-over-Year Growth %]
    CASE @SelectedView
        WHEN 'D' THEN
            CASE WHEN PY_NetAmount = 0 THEN 0
            ELSE (CY_NetAmount - PY_NetAmount) * 100.0 / PY_NetAmount END
        WHEN 'G' THEN
            CASE WHEN PY_TransactionCount = 0 THEN 0
            ELSE (CY_TransactionCount - PY_TransactionCount) * 100.0 / PY_TransactionCount END
        WHEN 'A' THEN
            CASE
                WHEN PY_TransactionCount = 0 OR CY_TransactionCount = 0 THEN 0
                WHEN (PY_NetAmount / PY_TransactionCount) = 0 THEN 0
                ELSE ((CY_NetAmount / CY_TransactionCount) - (PY_NetAmount / PY_TransactionCount)) * 100.0 / (PY_NetAmount / PY_TransactionCount)
            END
        ELSE 0
    END AS PercentInc,

    -- SortOrder for consistent ordering (Total = 0, PODs = 1,2,3...)
    SortOrder

FROM FinalSet
WHERE ReportDate <= @EndDate
  AND ReportDate < CAST(SYSDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time' AS DATE)
ORDER BY
    Date ASC,
    SortOrder ASC
OPTION (MAXRECURSION 1000);
