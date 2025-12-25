-- =============================================
-- Test: operating-periods/tests/test-ssms.sql
-- Purpose: Local SQL Server testing for Operating Periods query.
-- =============================================

-- 1. Setup Test Parameters
DECLARE @SiteIds VARCHAR(MAX) = '3187';
DECLARE @StartDate DATE = '2025-11-20';
DECLARE @EndDate DATE = '2025-11-30';
DECLARE @SelectedView VARCHAR(1) = 'D';

-- 2. Mock OutSystems Tables (for local testing)
-- Replace {Table} with actual table names (e.g., OSADMIN.OSUSR_...) 
-- or use the real DB environment if connected.

WITH TargetPeriods AS (
    SELECT 
        p.Id AS OperatingPeriodId, 
        p.SiteId, 
        ISNULL(s.DisplayName, s.Name) AS SiteName,
        p.BusDate, 
        ISNULL((SELECT SUM(ISNULL(ExpectedAmount,0)) FROM {SWCPeriodTender} WHERE OperatingPeriodId = p.Id), 0) AS ExpectedTotal, 
        ISNULL((SELECT SUM(ISNULL(CountedAmount,0)) FROM {SWCPeriodTender} WHERE OperatingPeriodId = p.Id), 0) AS ActualTotal, 
        ISNULL(p.TotalVariance, 0) AS VarianceTotal,
        (SELECT SUM(ISNULL(TransactionCount,0)) FROM {SWCPeriodTender} WHERE OperatingPeriodId = p.Id) AS RowTotalGuests
    FROM {SWCPeriod} p
    INNER JOIN {Site} s ON p.SiteId = s.Id
    WHERE p.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
      AND p.BusDate BETWEEN @StartDate AND @EndDate
),

ActiveTenderTypes AS (
    SELECT DISTINCT tt.Id AS TenderTypeId, tt.Name
    FROM {TenderType} tt
    INNER JOIN {SWCPeriodTender} spt ON tt.Id = spt.TenderTypeId
    INNER JOIN TargetPeriods tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
),

 RowTenderRaw AS (
    SELECT 
        tp.OperatingPeriodId,
        att.TenderTypeId,
        att.Name,
        SUM(ISNULL(spt.CountedAmount, 0)) AS Amt,
        SUM(ISNULL(spt.TransactionCount, 0)) AS Cnt
    FROM TargetPeriods tp
    CROSS JOIN ActiveTenderTypes att
    LEFT JOIN {SWCPeriodTender} spt ON tp.OperatingPeriodId = spt.OperatingPeriodId AND att.TenderTypeId = spt.TenderTypeId
    GROUP BY tp.OperatingPeriodId, att.TenderTypeId, att.Name
),

TotalTenderRaw AS (
    SELECT 
        NULL AS OperatingPeriodId,
        TenderTypeId,
        Name,
        SUM(Amt) AS Amt,
        SUM(Cnt) AS Cnt
    FROM RowTenderRaw
    GROUP BY TenderTypeId, Name
),

CombinedRaw AS (
    SELECT * FROM RowTenderRaw
    UNION ALL
    SELECT * FROM TotalTenderRaw
),

FinalItems AS (
    -- A. Expected Total Takings (Position 10)
    SELECT 
        tp.OperatingPeriodId, tp.SiteId, tp.SiteName, tp.BusDate,
        NULL AS TenderTypeId, 'Expected Total Takings' AS Name, 10 AS SortOrder,
        CASE WHEN @SelectedView = 'D' THEN tp.ExpectedTotal ELSE 0 END AS Value
    FROM TargetPeriods tp
    UNION ALL
    SELECT NULL, 0, 'Grand Total', NULL, NULL, 'Expected Total Takings', 10, 
        CASE WHEN @SelectedView = 'D' THEN SUM(ExpectedTotal) ELSE 0 END 
    FROM TargetPeriods

    UNION ALL

    -- B. Dynamic Tenders (Position 50)
    SELECT 
        c.OperatingPeriodId, 
        ISNULL(tp.SiteId, 0) AS SiteId, 
        ISNULL(tp.SiteName, 'Grand Total') AS SiteName, 
        tp.BusDate,
        c.TenderTypeId, c.Name, 50,
        CASE @SelectedView 
            WHEN 'D' THEN c.Amt
            WHEN 'G' THEN CAST(c.Cnt AS DECIMAL(18,2))
            WHEN 'A' THEN c.Amt / NULLIF(c.Cnt, 0) ELSE 0 END
    FROM CombinedRaw c
    LEFT JOIN TargetPeriods tp ON c.OperatingPeriodId = tp.OperatingPeriodId

    UNION ALL

    -- C. Actual Total Takings (Position 90)
    SELECT 
        tp.OperatingPeriodId, tp.SiteId, tp.SiteName, tp.BusDate,
        NULL, 'Actual Total Takings', 90,
        CASE @SelectedView 
            WHEN 'D' THEN tp.ActualTotal
            WHEN 'G' THEN CAST(tp.RowTotalGuests AS DECIMAL(18,2))
            WHEN 'A' THEN tp.ActualTotal / NULLIF(tp.RowTotalGuests, 0) ELSE 0 END
    FROM TargetPeriods tp
    UNION ALL
    SELECT NULL, 0, 'Grand Total', NULL, NULL, 'Actual Total Takings', 90,
        CASE @SelectedView 
            WHEN 'D' THEN SUM(ActualTotal)
            WHEN 'G' THEN CAST(SUM(RowTotalGuests) AS DECIMAL(18,2))
            WHEN 'A' THEN SUM(ActualTotal) / NULLIF(SUM(RowTotalGuests), 0) ELSE 0 END 
    FROM TargetPeriods

    UNION ALL

    -- D. Variance (Position 100)
    SELECT 
        tp.OperatingPeriodId, tp.SiteId, tp.SiteName, tp.BusDate,
        NULL, 'Variance', 100,
        CASE WHEN @SelectedView = 'D' THEN tp.VarianceTotal ELSE 0 END
    FROM TargetPeriods tp
    UNION ALL
    SELECT NULL, 0, 'Grand Total', NULL, NULL, 'Variance', 100, 
        CASE WHEN @SelectedView = 'D' THEN SUM(VarianceTotal) ELSE 0 END 
    FROM TargetPeriods

    UNION ALL

    -- E. Information (Position 110)
    SELECT tp.OperatingPeriodId, tp.SiteId, tp.SiteName, tp.BusDate, NULL, 'Information', 110, 0 
    FROM TargetPeriods tp
    UNION ALL
    SELECT NULL, 0, 'Grand Total', NULL, NULL, 'Information', 110, 0
    FROM TargetPeriods
)

SELECT SiteId, SiteName, BusDate, TenderTypeId, Name, CAST(Value AS DECIMAL(18,2)) AS Value, SortOrder 
FROM FinalItems
ORDER BY 
    CASE WHEN OperatingPeriodId IS NULL THEN 0 ELSE 1 END, 
    BusDate,
    SiteName,
    OperatingPeriodId,
    SortOrder,
    Name;
