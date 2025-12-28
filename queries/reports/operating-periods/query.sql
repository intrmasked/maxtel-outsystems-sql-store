-- =============================================
-- Query: operating-periods/query.sql
-- Version: v1.0.0
-- Purpose: Retrieves dynamic tender data and fixed metrics (Expected, Actual, Variance) for the Operating Periods screen.
-- Note: Includes Grand Total row (OperatingPeriodId IS NULL).
-- =============================================

/* 
    OUTSYSTEMS PARAMETERS:
    - SiteIds (Text)       → ⚠️ Expand Inline = YES ⚠️
    - StartDate (Date)     → Expand Inline = No
    - EndDate (Date)       → Expand Inline = No
    - SelectedView (Text)  → 'D' (Dollars), 'G' (Guests), 'A' (Average)
*/

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
    WHERE p.SiteId IN (@SiteIds)
      AND p.BusDate BETWEEN @StartDate AND @EndDate
),

-- Identify all tenders active across any of the selected sites in the date range
ActiveTenderTypes AS (
    SELECT DISTINCT tt.Id AS TenderTypeId, tt.Name
    FROM {TenderType} tt
    INNER JOIN {SWCPeriodTender} spt ON tt.Id = spt.TenderTypeId
    INNER JOIN TargetPeriods tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
),

-- Raw Row Data (Amount and Count) for weighted averages
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

-- Grand Total Row raw data using aggregation of row data
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

-- Combine Row and Total Raw Data
CombinedRaw AS (
    SELECT tp.BusDate, r.* FROM RowTenderRaw r INNER JOIN TargetPeriods tp ON r.OperatingPeriodId = tp.OperatingPeriodId
    UNION ALL
    -- Daily Grand Totals Raw
    SELECT tp.BusDate, NULL AS OperatingPeriodId, r.TenderTypeId, r.Name, SUM(r.Amt) AS Amt, SUM(r.Cnt) AS Cnt
    FROM RowTenderRaw r
    INNER JOIN TargetPeriods tp ON r.OperatingPeriodId = tp.OperatingPeriodId
    GROUP BY tp.BusDate, r.TenderTypeId, r.Name
    UNION ALL
    -- Overall Grand Totals Raw
    SELECT NULL AS BusDate, NULL AS OperatingPeriodId, TenderTypeId, Name, SUM(Amt) AS Amt, SUM(Cnt) AS Cnt
    FROM RowTenderRaw
    GROUP BY TenderTypeId, Name
),

-- Final Formatting of Columns (Expected, Tenders, Actual, Variance, Information)
FinalItems AS (
    -- A. Expected Total Takings (Position 10) - DOLLARS ONLY
    SELECT 
        tp.OperatingPeriodId, tp.SiteId, tp.SiteName, tp.BusDate,
        NULL AS TenderTypeId, 'Expected Total Takings' AS Name, 10 AS SortOrder,
        tp.ExpectedTotal AS Value
    FROM TargetPeriods tp
    WHERE @SelectedView = 'D'
    UNION ALL
    -- Daily Grand Total
    SELECT NULL, 0, 'Grand Total', tp.BusDate, NULL, 'Expected Total Takings', 10, SUM(tp.ExpectedTotal)
    FROM TargetPeriods tp
    WHERE @SelectedView = 'D'
    GROUP BY tp.BusDate
    UNION ALL
    -- Overall Grand Total
    SELECT NULL, 0, 'Grand Total', NULL, NULL, 'Expected Total Takings', 10, Total
    FROM (SELECT SUM(ExpectedTotal) AS Total FROM TargetPeriods WHERE @SelectedView = 'D' HAVING COUNT(*) > 0) t

    UNION ALL

    -- B. Dynamic Tenders (Position 50)
    SELECT 
        c.OperatingPeriodId, 
        ISNULL(tp.SiteId, 0) AS SiteId, 
        ISNULL(tp.SiteName, 'Grand Total') AS SiteName, 
        c.BusDate,
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
    -- Daily Grand Total
    SELECT NULL, 0, 'Grand Total', tp.BusDate, NULL, 'Actual Total Takings', 90,
        CASE @SelectedView 
            WHEN 'D' THEN SUM(ActualTotal)
            WHEN 'G' THEN CAST(SUM(RowTotalGuests) AS DECIMAL(18,2))
            WHEN 'A' THEN SUM(ActualTotal) / NULLIF(SUM(RowTotalGuests), 0) ELSE 0 END 
    FROM TargetPeriods tp
    GROUP BY tp.BusDate
    UNION ALL
    -- Overall Grand Total
    SELECT NULL, 0, 'Grand Total', NULL, NULL, 'Actual Total Takings', 90,
        CASE @SelectedView 
            WHEN 'D' THEN SUM(ActualTotal)
            WHEN 'G' THEN CAST(SUM(RowTotalGuests) AS DECIMAL(18,2))
            WHEN 'A' THEN SUM(ActualTotal) / NULLIF(SUM(RowTotalGuests), 0) ELSE 0 END 
    FROM TargetPeriods

    UNION ALL

    -- D. Variance (Position 100) - DOLLARS ONLY
    SELECT 
        tp.OperatingPeriodId, tp.SiteId, tp.SiteName, tp.BusDate,
        NULL, 'Variance', 100,
        tp.VarianceTotal
    FROM TargetPeriods tp
    WHERE @SelectedView = 'D'
    UNION ALL
    -- Daily Grand Total
    SELECT NULL, 0, 'Grand Total', tp.BusDate, NULL, 'Variance', 100, SUM(tp.VarianceTotal)
    FROM TargetPeriods tp
    WHERE @SelectedView = 'D'
    GROUP BY tp.BusDate
    UNION ALL
    -- Overall Grand Total
    SELECT NULL, 0, 'Grand Total', NULL, NULL, 'Variance', 100, Total
    FROM (SELECT SUM(VarianceTotal) AS Total FROM TargetPeriods WHERE @SelectedView = 'D' HAVING COUNT(*) > 0) t

    UNION ALL

    -- E. Information (Position 110)
    SELECT tp.OperatingPeriodId, tp.SiteId, tp.SiteName, tp.BusDate, NULL, 'Information', 110, 0 
    FROM TargetPeriods tp
    UNION ALL
    -- Overall Grand Total Only
    SELECT NULL, 0, 'Grand Total', NULL, NULL, 'Information', 110, 0
    FROM TargetPeriods
)

SELECT SiteId, SiteName, BusDate, TenderTypeId, Name, CAST(Value AS DECIMAL(18,2)) AS Value, SortOrder 
FROM FinalItems
ORDER BY 
    CASE WHEN BusDate IS NULL THEN 0 ELSE 1 END, -- Overall Grand Total Absolute First
    BusDate,
    CASE WHEN OperatingPeriodId IS NULL THEN 0 ELSE 1 END, -- Daily Grand Total First within date
    SiteName,
    OperatingPeriodId,
    SortOrder,
    Name
OPTION (RECOMPILE);
