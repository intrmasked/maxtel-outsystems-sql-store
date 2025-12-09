-- =============================================
-- Test 1: Pod Totals by Date
-- Purpose: Shows total sales per pod per date
-- Created: 2025-12-09
-- =============================================

-- Test Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';
DECLARE @Pod VARCHAR(50) = NULL;  -- NULL = All Pods, 'CSO' = Kiosk only, 'FC' = Counter only, 'DT' = Drive-Thru only, 'Total' = Total only

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

TotalData AS (
    SELECT
        ReportDate,
        'Total' AS Pod,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount
    FROM CleanedData
    GROUP BY ReportDate
)

-- Output with verification columns
SELECT
    ReportDate AS Date,
    Pod,
    CY_NetAmount AS Sales,
    CY_TransactionCount AS GuestCount,
    CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END AS AvgCheck,
    ROW_NUMBER() OVER (PARTITION BY ReportDate ORDER BY
        CASE Pod
            WHEN 'Total' THEN 0
            ELSE 1
        END,
        Pod
    ) AS PodSequence
FROM (
    SELECT * FROM CleanedData
    UNION ALL
    SELECT * FROM TotalData
) Combined
WHERE ReportDate <= @EndDate
  AND (@Pod IS NULL OR Pod = @Pod)  -- Filter by pod if specified
ORDER BY Date ASC, PodSequence ASC
OPTION (MAXRECURSION 1000);
