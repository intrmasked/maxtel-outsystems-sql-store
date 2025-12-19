/*
   ===================================================================================
   TEST QUERY: PRODUCT SALES BY DAY PART - SSMS VERSION
   ===================================================================================
   
   This is the SSMS-compatible version for testing in SQL Server Management Studio.
   Uses STRING_SPLIT() to parse comma-separated @SiteIds parameter.
   
   NOTE: The production query (../query.sql) uses OutSystems Expand Inline = YES
   which doesn't require STRING_SPLIT - OutSystems injects values directly.
   
   REQUIREMENTS:
   - SQL Server 2016+ (for STRING_SPLIT function)
   - Replace {Site} and {SalesFact} with actual table names (e.g., [dbo].[Site])
   
   ===================================================================================
*/

DECLARE @SiteIds NVARCHAR(MAX) = '3187';  -- Comma-separated Site IDs
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';
DECLARE @SelectedView VARCHAR(1) = 'D';

WITH

InputVar AS (
    SELECT @SelectedView AS SelectedView
),

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

DayPartDefs AS (
    SELECT 'Overnight (00-05)' AS DayPartLabel, 1 AS SortOrder
    UNION ALL SELECT 'Breakfast (05-11)', 2
    UNION ALL SELECT 'Day (11-17)', 3
    UNION ALL SELECT 'Night (17-24)', 4
),

-- SSMS: Use STRING_SPLIT to parse comma-separated Site IDs
SiteList AS (
    SELECT
        s.Id AS SiteId,
        ISNULL(s.DisplayName, s.Name) AS SiteName
    FROM {Site} s
    WHERE s.Id IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
),

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

RawData AS (
    SELECT
        sf.SiteId,
        CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time') AS NZ_DateTime,
        CASE WHEN sf.CalendarDate BETWEEN @StartDate AND @EndDate THEN 'CY' ELSE 'PY' END AS YearType,
        CASE WHEN sf.CalendarDate BETWEEN @StartDate AND @EndDate THEN sf.CalendarDate ELSE DATEADD(DAY, 364, sf.CalendarDate) END AS ReportDate,
        sf.NetAmount,
        sf.TransactionCount
    FROM {SalesFact} sf
    WHERE sf.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
      AND sf.CalendarDate BETWEEN DATEADD(DAY, -364, @StartDate) AND @EndDate
      AND sf.DatePeriodDimensionId = 15
      AND sf.ProductMenuId IS NULL
      AND sf.ProductSaleTypeId = 1
      AND sf.TenderTypeId IS NULL
      AND sf.OperationId IS NULL
      AND sf.OperationKindId IS NULL
      AND sf.SWCCashDrawerId IS NULL
      AND sf.SaleTypeId IS NULL
      AND sf.Pod = ''
      AND ISNULL(sf.PosId, 0) = 0
),

AggregatedData AS (
    SELECT
        SiteId,
        CAST(NZ_DateTime AS DATE) AS NZ_Date,
        ReportDate,
        CASE
            WHEN DATEPART(HOUR, NZ_DateTime) >= 0  AND DATEPART(HOUR, NZ_DateTime) < 5  THEN 'Overnight (00-05)'
            WHEN DATEPART(HOUR, NZ_DateTime) >= 5  AND DATEPART(HOUR, NZ_DateTime) < 11 THEN 'Breakfast (05-11)'
            WHEN DATEPART(HOUR, NZ_DateTime) >= 11 AND DATEPART(HOUR, NZ_DateTime) < 17 THEN 'Day (11-17)'
            WHEN DATEPART(HOUR, NZ_DateTime) >= 17 THEN 'Night (17-24)'
        END AS DayPartLabel,
        SUM(CASE WHEN YearType = 'CY' THEN NetAmount ELSE 0 END) AS CY_NetAmount,
        SUM(CASE WHEN YearType = 'CY' THEN TransactionCount ELSE 0 END) AS CY_TransactionCount,
        SUM(CASE WHEN YearType = 'PY' THEN NetAmount ELSE 0 END) AS PY_NetAmount,
        SUM(CASE WHEN YearType = 'PY' THEN TransactionCount ELSE 0 END) AS PY_TransactionCount
    FROM RawData
    GROUP BY
        SiteId, CAST(NZ_DateTime AS DATE), ReportDate,
        CASE
            WHEN DATEPART(HOUR, NZ_DateTime) >= 0  AND DATEPART(HOUR, NZ_DateTime) < 5  THEN 'Overnight (00-05)'
            WHEN DATEPART(HOUR, NZ_DateTime) >= 5  AND DATEPART(HOUR, NZ_DateTime) < 11 THEN 'Breakfast (05-11)'
            WHEN DATEPART(HOUR, NZ_DateTime) >= 11 AND DATEPART(HOUR, NZ_DateTime) < 17 THEN 'Day (11-17)'
            WHEN DATEPART(HOUR, NZ_DateTime) >= 17 THEN 'Night (17-24)'
        END
),

CleanedData AS (
    SELECT
        s.ReportDate, s.SiteId, s.SiteName, s.DayPartLabel, s.SortOrder,
        ISNULL(a.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(a.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(a.PY_NetAmount, 0) AS PY_NetAmount,
        ISNULL(a.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM Scaffold s
    LEFT JOIN AggregatedData a ON s.ReportDate = a.ReportDate AND s.DayPartLabel = a.DayPartLabel AND s.SiteId = a.SiteId
),

TotalData AS (
    SELECT ReportDate, SiteId, SiteName, 'Total (00-24)' AS DayPartLabel, 0 AS SortOrder,
        SUM(CY_NetAmount) AS CY_NetAmount, SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount, SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM CleanedData
    GROUP BY ReportDate, SiteId, SiteName
),

CombinedSet AS (
    SELECT * FROM CleanedData
    UNION ALL
    SELECT * FROM TotalData
)

SELECT
    ReportDate AS Date, SiteName, DayPartLabel,
    CASE (SELECT SelectedView FROM InputVar)
        WHEN 'D' THEN CY_NetAmount
        WHEN 'G' THEN CAST(CY_TransactionCount AS DECIMAL(18,2))
        WHEN 'A' THEN CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END
        ELSE 0
    END AS Value,
    CASE
        WHEN (SELECT SelectedView FROM InputVar) = 'A' THEN 0
        WHEN (SELECT SelectedView FROM InputVar) = 'D' THEN
             CASE WHEN MAX(CASE WHEN SortOrder = 0 THEN CY_NetAmount ELSE 0 END) OVER (PARTITION BY ReportDate, SiteId) = 0 THEN 0
                  ELSE CY_NetAmount * 100.0 / NULLIF(MAX(CASE WHEN SortOrder = 0 THEN CY_NetAmount ELSE 0 END) OVER (PARTITION BY ReportDate, SiteId), 0) END
        WHEN (SELECT SelectedView FROM InputVar) = 'G' THEN
             CASE WHEN MAX(CASE WHEN SortOrder = 0 THEN CY_TransactionCount ELSE 0 END) OVER (PARTITION BY ReportDate, SiteId) = 0 THEN 0
                  ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / NULLIF(MAX(CASE WHEN SortOrder = 0 THEN CY_TransactionCount ELSE 0 END) OVER (PARTITION BY ReportDate, SiteId), 0) END
        ELSE 0
    END AS PercentTotal,
    CASE (SELECT SelectedView FROM InputVar)
        WHEN 'D' THEN CASE WHEN PY_NetAmount = 0 THEN 0 ELSE (CY_NetAmount - PY_NetAmount) * 100.0 / PY_NetAmount END
        WHEN 'G' THEN CASE WHEN PY_TransactionCount = 0 THEN 0 ELSE (CAST(CY_TransactionCount AS DECIMAL(18,2)) - PY_TransactionCount) * 100.0 / PY_TransactionCount END
        WHEN 'A' THEN CASE WHEN PY_TransactionCount = 0 OR CY_TransactionCount = 0 THEN 0
                           WHEN (PY_NetAmount / PY_TransactionCount) = 0 THEN 0
                           ELSE ((CY_NetAmount / CY_TransactionCount) - (PY_NetAmount / PY_TransactionCount)) * 100.0 / (PY_NetAmount / PY_TransactionCount) END
        ELSE 0
    END AS PercentInc,
    SortOrder
FROM CombinedSet
ORDER BY Date ASC, SiteName ASC, SortOrder ASC;
