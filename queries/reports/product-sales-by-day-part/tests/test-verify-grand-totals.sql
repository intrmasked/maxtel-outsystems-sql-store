/*
   ===================================================================================
   TEST: VERIFY GRAND TOTALS - Product Sales by Day Part
   ===================================================================================
   
   PURPOSE:
   Validates that Grand Total rows (SiteName = 'Grand Totals') match the sum
   of individual daily data. Ensures no double-counting or missing data.
   
   EXPECTED RESULT:
   - All Diff_* columns should be 0 (or very close to 0 for decimals)
   - If any Diff is non-zero, there's a calculation error
   
   ===================================================================================
*/

DECLARE @SiteIds NVARCHAR(MAX) = '3187';
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';

WITH

Numbers AS (
    SELECT 0 AS N
    UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
),
AllNumbers AS (
    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)) - 1 AS N
    FROM Numbers n1 CROSS JOIN Numbers n2 CROSS JOIN Numbers n3 CROSS JOIN Numbers n4
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

SiteList AS (
    SELECT s.Id AS SiteId, ISNULL(s.DisplayName, s.Name) AS SiteName
    FROM {Site} s
    WHERE s.Id IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
),

Scaffold AS (
    SELECT d.ReportDate, p.DayPartLabel, p.SortOrder, site.SiteId, site.SiteName
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
        sf.TransactionCount,
        sf.PosId,
        sf.[DateTime]
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

DedupedData AS (
    SELECT
        SiteId, NZ_DateTime, YearType, ReportDate,
        MAX(NetAmount) AS NetAmount,
        MAX(TransactionCount) AS TransactionCount
    FROM RawData
    GROUP BY SiteId, NZ_DateTime, YearType, ReportDate, PosId, [DateTime]
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
    FROM DedupedData
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

-- Calculate what the Grand Totals SHOULD be (by summing CleanedData directly)
ExpectedTotals AS (
    -- Overall Total
    SELECT 
        'Total' AS DayPartLabel,
        SUM(CY_NetAmount) AS Expected_CY_NetAmount,
        SUM(CY_TransactionCount) AS Expected_CY_TransactionCount,
        SUM(PY_NetAmount) AS Expected_PY_NetAmount,
        SUM(PY_TransactionCount) AS Expected_PY_TransactionCount
    FROM CleanedData
    
    UNION ALL
    
    -- Per-DayPart Totals
    SELECT 
        DayPartLabel,
        SUM(CY_NetAmount),
        SUM(CY_TransactionCount),
        SUM(PY_NetAmount),
        SUM(PY_TransactionCount)
    FROM CleanedData
    GROUP BY DayPartLabel
),

-- Grand Totals from GROUPING SETS (what the query actually produces)
ActualTotals AS (
    SELECT 
        CASE 
            WHEN GROUPING(DayPartLabel) = 1 THEN 'Total'
            ELSE DayPartLabel
        END AS DayPartLabel,
        SUM(CY_NetAmount) AS Actual_CY_NetAmount,
        SUM(CY_TransactionCount) AS Actual_CY_TransactionCount,
        SUM(PY_NetAmount) AS Actual_PY_NetAmount,
        SUM(PY_TransactionCount) AS Actual_PY_TransactionCount
    FROM CleanedData
    GROUP BY GROUPING SETS (
        (),
        (DayPartLabel)
    )
)

-- Compare Expected vs Actual
SELECT 
    e.DayPartLabel,
    e.Expected_CY_NetAmount,
    a.Actual_CY_NetAmount,
    (e.Expected_CY_NetAmount - a.Actual_CY_NetAmount) AS Diff_CY_Net,
    e.Expected_CY_TransactionCount,
    a.Actual_CY_TransactionCount,
    (e.Expected_CY_TransactionCount - a.Actual_CY_TransactionCount) AS Diff_CY_Txn,
    e.Expected_PY_NetAmount,
    a.Actual_PY_NetAmount,
    (e.Expected_PY_NetAmount - a.Actual_PY_NetAmount) AS Diff_PY_Net,
    e.Expected_PY_TransactionCount,
    a.Actual_PY_TransactionCount,
    (e.Expected_PY_TransactionCount - a.Actual_PY_TransactionCount) AS Diff_PY_Txn,
    CASE 
        WHEN (e.Expected_CY_NetAmount - a.Actual_CY_NetAmount) = 0
         AND (e.Expected_CY_TransactionCount - a.Actual_CY_TransactionCount) = 0
         AND (e.Expected_PY_NetAmount - a.Actual_PY_NetAmount) = 0
         AND (e.Expected_PY_TransactionCount - a.Actual_PY_TransactionCount) = 0
        THEN '✓ PASS'
        ELSE '✗ FAIL'
    END AS Status
FROM ExpectedTotals e
JOIN ActualTotals a ON e.DayPartLabel = a.DayPartLabel
ORDER BY 
    CASE e.DayPartLabel 
        WHEN 'Total' THEN 0 
        WHEN 'Overnight (00-05)' THEN 1
        WHEN 'Breakfast (05-11)' THEN 2
        WHEN 'Day (11-17)' THEN 3
        WHEN 'Night (17-24)' THEN 4
    END;
