/*
   ===================================================================================
   TEST QUERY: PRODUCT SALES BY POS - SSMS VERSION
   ===================================================================================
   
   This is the SSMS-compatible version for testing in SQL Server Management Studio.
   Uses STRING_SPLIT() to parse comma-separated @SiteIds parameter.
   
   NOTE: The production query (../query.sql) uses OutSystems Expand Inline = YES
   which doesn't require STRING_SPLIT - OutSystems injects values directly.
   
   REQUIREMENTS:
   - SQL Server 2016+ (for STRING_SPLIT function)
   - Replace {Site} and {SalesFact} with actual table names
   
   ===================================================================================
*/

DECLARE @SiteIds NVARCHAR(MAX) = '3187';  -- Comma-separated Site IDs
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';
DECLARE @SelectedView VARCHAR(1) = 'D';

WITH

SiteList AS (
    SELECT s.Id AS SiteId, ISNULL(s.DisplayName, s.Name) AS SiteName
    FROM {Site} s
    WHERE s.Id IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
),

DateList AS (
    SELECT @StartDate AS ReportDate
    UNION ALL
    SELECT DATEADD(DAY, 1, ReportDate)
    FROM DateList
    WHERE ReportDate < @EndDate
),

RawDataPoints AS (
    SELECT
        sf.CalendarDate AS ReportDate,
        sf.[DateTime],
        sf.Pod,
        sf.PosId,
        sf.SiteId,
        sf.TransactionCount AS CY_TransactionCount,
        sf.NetAmount AS CY_NetAmount,
        0 AS PY_TransactionCount,
        0 AS PY_NetAmount
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
      AND sf.SaleTypeId IS NULL
      AND sf.PosId IS NOT NULL AND sf.PosId <> 0 -- Exclude Summary Rows
      AND sf.Pod IS NOT NULL AND sf.Pod <> ''

    UNION ALL

    SELECT
        DATEADD(DAY, 364, sf.CalendarDate) AS ReportDate,
        sf.[DateTime],
        sf.Pod,
        sf.PosId,
        sf.SiteId,
        0, 0,
        sf.TransactionCount,
        sf.NetAmount
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
      AND sf.PosId IS NOT NULL AND sf.PosId <> 0 -- Exclude Summary Rows
      AND sf.Pod IS NOT NULL AND sf.Pod <> ''
),

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

AggregatedData AS (
    SELECT SiteId, ReportDate, Pod,
        SUM(CY_NetAmount) AS CY_NetAmount, SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount, SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM DedupedData
    GROUP BY SiteId, ReportDate, Pod
),

ActivePods AS (
    SELECT DISTINCT SiteId, Pod
    FROM AggregatedData
    WHERE CY_TransactionCount > 0 OR CY_NetAmount <> 0
),

GridData AS (
    SELECT
        s.SiteId, s.SiteName, d.ReportDate, p.Pod,
        ISNULL(a.CY_NetAmount, 0) AS CY_NetAmount, ISNULL(a.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(a.PY_NetAmount, 0) AS PY_NetAmount, ISNULL(a.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM SiteList s
    CROSS JOIN DateList d
    CROSS JOIN (SELECT DISTINCT Pod FROM ActivePods) p
    LEFT JOIN AggregatedData a ON s.SiteId = a.SiteId AND d.ReportDate = a.ReportDate AND p.Pod = a.Pod
),

FinalSet AS (
    SELECT SiteId, SiteName, ReportDate, Pod, CY_NetAmount, CY_TransactionCount, PY_NetAmount, PY_TransactionCount,
        SUM(CY_NetAmount) OVER(PARTITION BY SiteId, ReportDate) AS DailyTotal_Net,
        SUM(CY_TransactionCount) OVER(PARTITION BY SiteId, ReportDate) AS DailyTotal_Txn,
        ROW_NUMBER() OVER (PARTITION BY SiteId, ReportDate ORDER BY Pod) AS SortOrder
    FROM GridData
    UNION ALL
    SELECT SiteId, SiteName, ReportDate, 'Total' AS Pod,
        SUM(CY_NetAmount), SUM(CY_TransactionCount), SUM(PY_NetAmount), SUM(PY_TransactionCount),
        SUM(CY_NetAmount), SUM(CY_TransactionCount), 0 AS SortOrder
    FROM GridData
    GROUP BY SiteId, SiteName, ReportDate
)

SELECT
    ReportDate AS Date, SiteId, SiteName, Pod,
    CASE @SelectedView
        WHEN 'D' THEN CY_NetAmount
        WHEN 'G' THEN CAST(CY_TransactionCount AS DECIMAL(18,2))
        WHEN 'A' THEN CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END
        ELSE 0
    END AS Value,
    CASE
        WHEN @SelectedView = 'A' THEN 0
        WHEN @SelectedView = 'D' THEN CASE WHEN DailyTotal_Net = 0 THEN 0 ELSE CY_NetAmount * 100.0 / DailyTotal_Net END
        WHEN @SelectedView = 'G' THEN CASE WHEN DailyTotal_Txn = 0 THEN 0 ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / DailyTotal_Txn END
        ELSE 0
    END AS PercentTotal,
    CASE @SelectedView
        WHEN 'D' THEN CASE WHEN PY_NetAmount = 0 THEN 0 ELSE (CY_NetAmount - PY_NetAmount) * 100.0 / PY_NetAmount END
        WHEN 'G' THEN CASE WHEN PY_TransactionCount = 0 THEN 0 ELSE (CY_TransactionCount - PY_TransactionCount) * 100.0 / PY_TransactionCount END
        WHEN 'A' THEN CASE WHEN PY_TransactionCount = 0 OR CY_TransactionCount = 0 THEN 0
                           WHEN (PY_NetAmount / PY_TransactionCount) = 0 THEN 0
                           ELSE ((CY_NetAmount / CY_TransactionCount) - (PY_NetAmount / PY_TransactionCount)) * 100.0 / (PY_NetAmount / PY_TransactionCount) END
        ELSE 0
    END AS PercentInc,
    SortOrder
FROM FinalSet
WHERE ReportDate <= @EndDate
  AND ReportDate < CAST(SYSDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time' AS DATE)
ORDER BY Date ASC, SiteName ASC, SortOrder ASC
OPTION (MAXRECURSION 1000, RECOMPILE);
