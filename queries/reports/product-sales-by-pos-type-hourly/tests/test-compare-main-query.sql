-- =============================================
-- Test: Compare Main Query Output with Expected Structure
-- Purpose: Run main query and validate output format and totals
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';
DECLARE @SelectedView VARCHAR(1) = 'D';  -- Test with Dollar Sales view

PRINT '=== MAIN QUERY OUTPUT (Sales View) ==='
PRINT 'Expected: Long format with Hour, Pod, Sales, PercentTotal, PercentInc'
PRINT 'Expected rows: ~100 (24 hours × N pods + N pods for Total Day)'
PRINT ''

-- Run full main query
WITH

Hours AS (
    SELECT 0 AS HourStart
    UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14
    UNION ALL SELECT 15 UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
),

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

Scaffold AS (
    SELECT
        h.HourStart,
        REPLICATE('0', 2 - LEN(CAST(h.HourStart AS VARCHAR))) + CAST(h.HourStart AS VARCHAR) + '-' +
        REPLICATE('0', 2 - LEN(CAST((h.HourStart + 1) % 24 AS VARCHAR))) + CAST((h.HourStart + 1) % 24 AS VARCHAR) AS Hour,
        p.Pod,
        h.HourStart AS SortOrder
    FROM Hours h
    CROSS JOIN AllPods p
),

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

HourlyTotals AS (
    SELECT
        Hour,
        SUM(CY_NetAmount) AS Total_CY_NetAmount,
        SUM(CY_TransactionCount) AS Total_CY_TransactionCount
    FROM MergedData
    GROUP BY Hour
),

TotalDayData AS (
    SELECT
        'Total Day' AS Hour,
        Pod,
        9999 AS SortOrder,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM MergedData
    GROUP BY Pod
),

TotalDayTotals AS (
    SELECT
        'Total Day' AS Hour,
        SUM(CY_NetAmount) AS Total_CY_NetAmount,
        SUM(CY_TransactionCount) AS Total_CY_TransactionCount
    FROM TotalDayData
),

CombinedData AS (
    SELECT
        Hour, Pod, SortOrder, CY_NetAmount, CY_TransactionCount, PY_NetAmount, PY_TransactionCount
    FROM MergedData
    UNION ALL
    SELECT
        Hour, Pod, SortOrder, CY_NetAmount, CY_TransactionCount, PY_NetAmount, PY_TransactionCount
    FROM TotalDayData
),

AllTotals AS (
    SELECT Hour, Total_CY_NetAmount, Total_CY_TransactionCount FROM HourlyTotals
    UNION ALL
    SELECT Hour, Total_CY_NetAmount, Total_CY_TransactionCount FROM TotalDayTotals
)

SELECT
    cd.Hour,
    cd.Pod,

    -- Sales
    CASE
        WHEN (@SelectedView) = 'D' THEN cd.CY_NetAmount
        WHEN (@SelectedView) = 'G' THEN CAST(cd.CY_TransactionCount AS DECIMAL(18,2))
        WHEN (@SelectedView) = 'A' THEN
            CASE WHEN cd.CY_TransactionCount = 0 THEN 0
            ELSE cd.CY_NetAmount / cd.CY_TransactionCount END
        ELSE 0
    END AS Sales,

    -- PercentTotal
    CASE
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
            ELSE ((cd.CY_NetAmount / cd.CY_TransactionCount) - (cd.PY_NetAmount / cd.PY_TransactionCount)) * 100.0 / (cd.PY_NetAmount / cd.PY_TransactionCount) END
        ELSE 0
    END AS PercentInc

FROM CombinedData cd
LEFT JOIN AllTotals t ON cd.Hour = t.Hour

ORDER BY cd.SortOrder ASC, cd.Pod ASC;

PRINT ''
PRINT '=== VALIDATION CHECKS ==='
PRINT 'Check 1: Hour format should be 00-01, 01-02, ... 23-24, Total Day'
PRINT 'Check 2: Each hour should have N rows (one per pod)'
PRINT 'Check 3: PercentTotal per hour should sum to ~100%'
PRINT 'Check 4: Total Day row should match sum of all 24 hours'
PRINT 'Check 5: All Sales values should be >= 0'
