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

-- 1. Identify all requested sites from comma-separated list
WITH SiteList AS (
    -- In OutSystems, we normally use a built-in function or STRING_SPLIT
    -- This assumes @SiteIds is a comma-separated string handled by the calling logic
    -- For the Advanced SQL, we treat it as an expanded IN clause ( handled elsewhere)
    -- But for grid generation, we need to extract them.
    SELECT Id, ISNULL(DisplayName, Name) AS SiteName
    FROM {Site}
    WHERE Id IN (@SiteIds)
      AND EXISTS (
          SELECT 1 FROM {SWCPeriod} p 
          WHERE p.SiteId = {Site}.Id 
            AND p.BusDate BETWEEN @StartDate AND @EndDate
      )
),

-- 2. Generate Recursive Date List for the range
DateList AS (
    SELECT @StartDate AS BusDate
    UNION ALL
    SELECT DATEADD(day, 1, BusDate)
    FROM DateList
    WHERE BusDate < @EndDate
),

-- 3. Create the Grid (Every Site x Every Date)
SiteDateGrid AS (
    SELECT s.Id AS SiteId, s.SiteName, d.BusDate
    FROM SiteList s
    CROSS JOIN DateList d
),

-- 4. Join actual period data into our grid
TargetPeriods AS (
    SELECT 
        g.SiteId, 
        g.SiteName,
        g.BusDate,
        p.Id AS OperatingPeriodId, 
        -- [FIX] Use SalesFact for ExpectedTotal to ensure "Sum of Decimals" accuracy (vs Sum of Rounded Integers)
        -- Matches filters from Product Sales By Day Part (Sales App)
        ISNULL((
            SELECT SUM(sf.NetAmount)
            FROM {SalesFact} sf
            WHERE sf.SiteId = g.SiteId
              AND sf.CalendarDate = g.BusDate
              -- Filters matching Sales App (Product Sales)
              AND sf.DatePeriodDimensionId = 15
              AND sf.ProductSaleTypeId = 1
              AND sf.ProductMenuId IS NULL
              AND sf.TenderTypeId IS NULL
              AND sf.OperationId IS NULL
              AND sf.OperationKindId IS NULL
              AND sf.SWCCashDrawerId IS NULL
              AND sf.SaleTypeId IS NULL
              AND sf.PosId IS NOT NULL AND sf.PosId <> 0
              AND sf.Pod IS NOT NULL AND sf.Pod <> ''
        ), 0) AS ExpectedTotal,
        
        ISNULL((SELECT SUM(ISNULL(CountedAmount,0)) FROM {SWCPeriodTender} WHERE OperatingPeriodId = p.Id), 0) AS ActualTotal, 
        ISNULL(p.TotalVariance, 0) AS VarianceTotal,
        ISNULL((SELECT SUM(ISNULL(TransactionCount,0)) FROM {SWCPeriodTender} WHERE OperatingPeriodId = p.Id), 0) AS RowTotalGuests
    FROM SiteDateGrid g
    LEFT JOIN {SWCPeriod} p ON g.SiteId = p.SiteId AND g.BusDate = p.BusDate
),

-- Identify all tenders active across any of the selected sites in the date range
ActiveTenderTypes AS (
    SELECT DISTINCT tt.Id AS TenderTypeId, tt.Name, tt.[Order]
    FROM {TenderType} tt
    INNER JOIN {SWCPeriodTender} spt ON tt.Id = spt.TenderTypeId
    INNER JOIN TargetPeriods tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
),

-- Raw Row Data (Amount and Count) for weighted averages
-- Now generates ALL tender types for ALL site/date combinations (even empty days)
RowTenderRaw AS (
    SELECT 
        tp.SiteId,
        tp.SiteName,
        tp.BusDate,
        tp.OperatingPeriodId,
        att.TenderTypeId,
        att.Name,
        att.[Order],
        ISNULL(SUM(spt.CountedAmount), 0) AS Amt,
        ISNULL(SUM(spt.TransactionCount), 0) AS Cnt
    FROM TargetPeriods tp
    CROSS JOIN ActiveTenderTypes att
    LEFT JOIN {SWCPeriodTender} spt ON tp.OperatingPeriodId = spt.OperatingPeriodId AND att.TenderTypeId = spt.TenderTypeId
    GROUP BY tp.SiteId, tp.SiteName, tp.BusDate, tp.OperatingPeriodId, att.TenderTypeId, att.Name, att.[Order]
),

-- Grand Total Row raw data using aggregation of row data
TotalTenderRaw AS (
    SELECT 
        NULL AS OperatingPeriodId,
        TenderTypeId,
        Name,
        [Order],
        SUM(Amt) AS Amt,
        SUM(Cnt) AS Cnt
    FROM RowTenderRaw
    GROUP BY TenderTypeId, Name, [Order]
),

-- Combine Row and Total Raw Data
CombinedRaw AS (
    -- All site/date/tender combinations (including 0-value days)
    SELECT SiteId, SiteName, BusDate, OperatingPeriodId, TenderTypeId, Name, [Order], Amt, Cnt 
    FROM RowTenderRaw
    UNION ALL
    -- Overall Grand Totals Raw
    SELECT 0 AS SiteId, 'Grand Total' AS SiteName, NULL AS BusDate, NULL AS OperatingPeriodId, TenderTypeId, Name, [Order], Amt, Cnt
    FROM TotalTenderRaw
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
    -- Overall Grand Total (Range Summary)
    SELECT NULL AS OperatingPeriodId, 0 AS SiteId, 'Grand Total' AS SiteName, NULL AS BusDate,
        NULL AS TenderTypeId, 'Expected Total Takings' AS Name, 10 AS SortOrder, Total
    FROM (SELECT SUM(ExpectedTotal) AS Total FROM TargetPeriods WHERE @SelectedView = 'D' HAVING COUNT(*) > 0) t

    UNION ALL

    -- B. Dynamic Tenders (Position 50 + Order)
    SELECT 
        c.OperatingPeriodId, 
        c.SiteId, 
        c.SiteName, 
        c.BusDate,
        c.TenderTypeId, c.Name, 50 + ISNULL(c.[Order], 999) AS SortOrder,
        CASE @SelectedView 
            WHEN 'D' THEN c.Amt
            WHEN 'G' THEN CAST(c.Cnt AS DECIMAL(18,2))
            WHEN 'A' THEN c.Amt / NULLIF(c.Cnt, 0) ELSE 0 END
    FROM CombinedRaw c

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
    -- Overall Grand Total (Range Summary)
    SELECT NULL, 0, 'Grand Total', NULL, NULL, 'Actual Total Takings', 90, Total
    FROM (
        SELECT 
            CASE @SelectedView 
                WHEN 'D' THEN SUM(ActualTotal)
                WHEN 'G' THEN CAST(SUM(RowTotalGuests) AS DECIMAL(18,2))
                WHEN 'A' THEN SUM(ActualTotal) / NULLIF(SUM(RowTotalGuests), 0) ELSE 0 END AS Total
        FROM TargetPeriods 
        HAVING COUNT(*) > 0
    ) t

    UNION ALL

    SELECT 
        tp.OperatingPeriodId, tp.SiteId, tp.SiteName, tp.BusDate,
        NULL, 'Variance', 100,
        tp.VarianceTotal
    FROM TargetPeriods tp
    WHERE @SelectedView = 'D'
    UNION ALL
    -- Overall Grand Total (Range Summary)
    SELECT NULL, 0, 'Grand Total', NULL, NULL, 'Variance', 100, Total
    FROM (SELECT SUM(VarianceTotal) AS Total FROM TargetPeriods WHERE @SelectedView = 'D' HAVING COUNT(*) > 0) t

    UNION ALL

    -- E. Information (Position 110)
    SELECT tp.OperatingPeriodId, tp.SiteId, tp.SiteName, tp.BusDate, NULL, 'Information', 110, 0 
    FROM TargetPeriods tp
    UNION ALL
    -- Overall Grand Total Only
    SELECT NULL, 0, 'Grand Total', NULL, NULL, 'Information', 110, 0
    FROM (SELECT 1 AS x FROM TargetPeriods HAVING COUNT(*) > 0) t
)

SELECT SiteId, SiteName, BusDate, TenderTypeId, Name, CAST(Value AS DECIMAL(18,2)) AS Value, SortOrder 
FROM FinalItems
ORDER BY 
    CASE WHEN BusDate IS NULL THEN 1 ELSE 0 END, -- Grand Total at bottom
    BusDate,
    SiteName,
    OperatingPeriodId,
    SortOrder,
    Name
OPTION (RECOMPILE, MAXRECURSION 1000);

