-- =============================================
-- Test 3: Verification - Check if Totals Match Sum of Pods
-- Purpose: Verify Total row equals sum of pod rows per date
-- Created: 2025-12-09
-- =============================================

-- Test Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';

WITH

DateList AS (
    SELECT @StartDate AS ReportDate
    UNION ALL
    SELECT DATEADD(DAY, 1, ReportDate)
    FROM DateList
    WHERE ReportDate < @EndDate
),

Scaffold AS (
    SELECT d.ReportDate, p.Pod
    FROM DateList d
    CROSS JOIN (
        SELECT 'FC' AS Pod
        UNION ALL
        SELECT 'DT'
        UNION ALL
        SELECT 'CSO'
    ) p
),

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
      AND Pod IN ('FC', 'DT', 'CSO')
      AND Pod IS NOT NULL AND Pod <> ''
    GROUP BY CalendarDate, Pod
),

CleanedData AS (
    SELECT
        s.ReportDate,
        s.Pod,
        ISNULL(cy.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(cy.CY_TransactionCount, 0) AS CY_TransactionCount
    FROM Scaffold s
    LEFT JOIN CY_RawData cy ON s.ReportDate = cy.ReportDate AND s.Pod = cy.Pod
),

PodSums AS (
    SELECT
        ReportDate,
        SUM(CY_NetAmount) AS PodSumSales,
        SUM(CY_TransactionCount) AS PodSumGuestCount
    FROM CleanedData
    GROUP BY ReportDate
),

TotalRow AS (
    SELECT
        ReportDate,
        SUM(CY_NetAmount) AS TotalSales,
        SUM(CY_TransactionCount) AS TotalGuestCount
    FROM CleanedData
    GROUP BY ReportDate
)

SELECT
    ps.ReportDate AS Date,
    ps.PodSumSales AS [Sum of Pods Sales],
    tr.TotalSales AS [Total Row Sales],
    CASE WHEN ABS(ps.PodSumSales - tr.TotalSales) < 0.01 THEN 'PASS' ELSE 'FAIL' END AS [Sales Match],
    ps.PodSumGuestCount AS [Sum of Pods GC],
    tr.TotalGuestCount AS [Total Row GC],
    CASE WHEN ps.PodSumGuestCount = tr.TotalGuestCount THEN 'PASS' ELSE 'FAIL' END AS [GC Match]
FROM PodSums ps
JOIN TotalRow tr ON ps.ReportDate = tr.ReportDate
ORDER BY ps.ReportDate
OPTION (MAXRECURSION 1000);
