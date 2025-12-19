/*
   ===================================================================================
   QUERY: PRODUCT SALES BY POS TYPE - MULTI-SITE SUPPORT v2.0.0
   ===================================================================================

   PURPOSE:
   Daily sales breakdown by Pod (Counter, Drive-Thru, Kiosk, Delivery) with YoY comparison.
   Supports multi-site reporting via comma-separated Site ID list.

   OUTSYSTEMS PARAMETERS:
   - SiteIds (Text)      → ⚠️ Expand Inline = YES ⚠️
   - StartDate (Date)    → Expand Inline = No
   - EndDate (Date)      → Expand Inline = No
   - SelectedView (Text) → Expand Inline = No  ('D'=Dollar, 'G'=Guest, 'A'=Average)

   KEY OPTIMIZATIONS:
   - Expand Inline = YES for @SiteIds (no SQL parsing needed)
   - UNION ALL pattern for parallel CY+PY index seeks
   - Pre-aggregation before scaffold building
   - Dynamic pod detection (only shows pods with data)
   - RECOMPILE hint for optimal execution plan

   FOR SSMS TESTING: See tests/test-ssms.sql
   ===================================================================================
*/

WITH

-- [STEP 0]: InputVar CTE (CRITICAL FOR OUTSYSTEMS!)
-- OutSystems "lazy parser" bug: parameters used late in query must be captured early
InputVar AS (
    SELECT @SelectedView AS SelectedView, @EndDate AS EndDate
),

-- [STEP 1]: Get Site List with Names
-- @SiteIds must have Expand Inline = YES in OutSystems!
SiteList AS (
    SELECT s.Id AS SiteId, ISNULL(s.DisplayName, s.Name) AS SiteName
    FROM {Site} s
    WHERE s.Id IN (@SiteIds)
),

-- [STEP 2]: Generate Date Range
DateList AS (
    SELECT @StartDate AS ReportDate
    UNION ALL
    SELECT DATEADD(DAY, 1, ReportDate)
    FROM DateList
    WHERE ReportDate < @EndDate
),

-- [STEP 3]: Fetch Data using UNION ALL for parallel index seeks
RawDataPoints AS (
    -- Query A: Current Year Data
    SELECT
        sf.SiteId,
        sf.CalendarDate AS ReportDate,
        sf.Pod,
        sf.NetAmount AS CY_NetAmount,
        sf.TransactionCount AS CY_TransactionCount,
        0 AS PY_NetAmount,
        0 AS PY_TransactionCount
    FROM {SalesFact} sf
    WHERE sf.SiteId IN (@SiteIds)
      AND sf.CalendarDate BETWEEN @StartDate AND @EndDate
      AND sf.DatePeriodDimensionId = 15
      AND sf.ProductSaleTypeId = 1
      AND sf.ProductMenuId IS NULL
      AND sf.TenderTypeId IS NULL
      AND sf.OperationId IS NULL
      AND sf.OperationKindId IS NULL
      AND sf.SWCCashDrawerId IS NULL
      AND sf.SaleTypeId IS NULL
      AND sf.PosId IS NOT NULL
      AND sf.Pod IS NOT NULL AND sf.Pod <> ''

    UNION ALL

    -- Query B: Previous Year Data (364 days back)
    SELECT
        sf.SiteId,
        DATEADD(DAY, 364, sf.CalendarDate) AS ReportDate,
        sf.Pod,
        0, 0,
        sf.NetAmount,
        sf.TransactionCount
    FROM {SalesFact} sf
    WHERE sf.SiteId IN (@SiteIds)
      AND sf.CalendarDate BETWEEN DATEADD(DAY, -364, @StartDate) AND DATEADD(DAY, -364, @EndDate)
      AND sf.DatePeriodDimensionId = 15
      AND sf.ProductSaleTypeId = 1
      AND sf.ProductMenuId IS NULL
      AND sf.TenderTypeId IS NULL
      AND sf.OperationId IS NULL
      AND sf.OperationKindId IS NULL
      AND sf.SWCCashDrawerId IS NULL
      AND sf.SaleTypeId IS NULL
      AND sf.PosId IS NOT NULL
      AND sf.Pod IS NOT NULL AND sf.Pod <> ''
),

-- [STEP 4]: Aggregate Combined Data Points
AggregatedData AS (
    SELECT
        SiteId,
        ReportDate,
        Pod,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM RawDataPoints
    GROUP BY SiteId, ReportDate, Pod
),

-- [STEP 5]: Identify Active Pods per Site (Only those with CY activity)
ActivePods AS (
    SELECT DISTINCT SiteId, Pod
    FROM AggregatedData
    WHERE CY_TransactionCount > 0 OR CY_NetAmount <> 0
),

-- [STEP 6]: Build Grid (Dates x Sites x Active Pods)
GridData AS (
    SELECT
        s.SiteId,
        s.SiteName,
        d.ReportDate,
        p.Pod,
        ISNULL(a.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(a.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(a.PY_NetAmount, 0) AS PY_NetAmount,
        ISNULL(a.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM SiteList s
    CROSS JOIN DateList d
    CROSS JOIN (SELECT DISTINCT Pod FROM ActivePods) p
    LEFT JOIN AggregatedData a 
        ON s.SiteId = a.SiteId 
        AND d.ReportDate = a.ReportDate 
        AND p.Pod = a.Pod
),

-- [STEP 7]: Calculate Totals & Sorting
FinalSet AS (
    -- Individual Pods
    SELECT
        SiteId,
        SiteName,
        ReportDate,
        Pod,
        CY_NetAmount,
        CY_TransactionCount,
        PY_NetAmount,
        PY_TransactionCount,
        SUM(CY_NetAmount) OVER(PARTITION BY SiteId, ReportDate) AS DailyTotal_Net,
        SUM(CY_TransactionCount) OVER(PARTITION BY SiteId, ReportDate) AS DailyTotal_Txn,
        ROW_NUMBER() OVER (PARTITION BY SiteId, ReportDate ORDER BY Pod) AS SortOrder
    FROM GridData

    UNION ALL

    -- Total Row per Site per Date
    SELECT
        SiteId,
        SiteName,
        ReportDate,
        'Total' AS Pod,
        SUM(CY_NetAmount),
        SUM(CY_TransactionCount),
        SUM(PY_NetAmount),
        SUM(PY_TransactionCount),
        SUM(CY_NetAmount),
        SUM(CY_TransactionCount),
        0 AS SortOrder
    FROM GridData
    GROUP BY SiteId, SiteName, ReportDate
)

-- [STEP 8]: Final Output
SELECT
    ReportDate AS Date,
    SiteName,
    Pod,

    -- VALUE
    CASE (SELECT SelectedView FROM InputVar)
        WHEN 'D' THEN CY_NetAmount
        WHEN 'G' THEN CAST(CY_TransactionCount AS DECIMAL(18,2))
        WHEN 'A' THEN CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END
        ELSE 0
    END AS Value,

    -- PERCENT TOTAL (per site's daily total)
    CASE
        WHEN (SELECT SelectedView FROM InputVar) = 'A' THEN 0
        WHEN (SELECT SelectedView FROM InputVar) = 'D' THEN
            CASE WHEN DailyTotal_Net = 0 THEN 0 ELSE CY_NetAmount * 100.0 / DailyTotal_Net END
        WHEN (SELECT SelectedView FROM InputVar) = 'G' THEN
            CASE WHEN DailyTotal_Txn = 0 THEN 0 ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / DailyTotal_Txn END
        ELSE 0
    END AS PercentTotal,

    -- PERCENT INC (YoY)
    CASE (SELECT SelectedView FROM InputVar)
        WHEN 'D' THEN
            CASE WHEN PY_NetAmount = 0 THEN 0 ELSE (CY_NetAmount - PY_NetAmount) * 100.0 / PY_NetAmount END
        WHEN 'G' THEN
            CASE WHEN PY_TransactionCount = 0 THEN 0 ELSE (CY_TransactionCount - PY_TransactionCount) * 100.0 / PY_TransactionCount END
        WHEN 'A' THEN
            CASE
                WHEN PY_TransactionCount = 0 OR CY_TransactionCount = 0 THEN 0
                WHEN (PY_NetAmount / PY_TransactionCount) = 0 THEN 0
                ELSE ((CY_NetAmount / CY_TransactionCount) - (PY_NetAmount / PY_TransactionCount)) * 100.0 / (PY_NetAmount / PY_TransactionCount)
            END
        ELSE 0
    END AS PercentInc,

    SortOrder

FROM FinalSet
WHERE ReportDate <= (SELECT EndDate FROM InputVar)
  AND ReportDate < CAST(SYSDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time' AS DATE)
ORDER BY
    Date ASC,
    SiteName ASC,
    SortOrder ASC
OPTION (MAXRECURSION 1000, RECOMPILE)
