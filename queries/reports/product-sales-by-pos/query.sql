/*
   ===================================================================================
   QUERY: PRODUCT SALES BY POS - v6.0 (Ultimate Optimization)
   ===================================================================================

   PURPOSE:
   Sales/transaction data by POS type with YoY comparison and Custom Sorting.
   Sort Order: Total -> CSO -> DT -> FC -> [Others]

   OPTIMIZATION STRATEGY:
   1. Pre-Aggregation inside UNION ALL (Reduces 100k+ rows to ~600 rows instantly).
   2. Grouping Sets on the tiny dataset for zero-cost Totals.
   3. Pre-calculated Sort Weights for simple sorting.

   OUTSYSTEMS PARAMETERS:
   - SiteIds (Text)      → ⚠️ Expand Inline = YES ⚠️
   - StartDate (Date)    → Expand Inline = No
   - EndDate (Date)      → Expand Inline = No
   - SelectedView (Text) → Expand Inline = No

   FOR SSMS TESTING: See tests/test-ssms.sql
   ===================================================================================
*/

WITH

InputVar AS (
    SELECT @SelectedView AS SelectedView
),

SiteList AS (
    SELECT s.Id AS SiteId, ISNULL(s.DisplayName, s.Name) AS SiteName
    FROM {Site} s
    WHERE s.Id IN (@SiteIds)
),

-- [WIN #1] Pre-Aggregation (Reduce Data Volume Immediately)
PreAggregatedData AS (
    -- CY Data
    SELECT
        sf.SiteId,
        sf.CalendarDate AS ReportDate,
        sf.Pod,
        SUM(sf.NetAmount) AS CY_NetAmount,
        SUM(sf.TransactionCount) AS CY_TransactionCount,
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
      AND sf.PosId IS NOT NULL AND sf.PosId <> 0
      AND sf.Pod IS NOT NULL AND sf.Pod <> ''
    GROUP BY sf.SiteId, sf.CalendarDate, sf.Pod

    UNION ALL

    -- PY Data
    SELECT
        sf.SiteId,
        DATEADD(DAY, 364, sf.CalendarDate) AS ReportDate,
        sf.Pod,
        0, 0,
        SUM(sf.NetAmount),
        SUM(sf.TransactionCount)
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
      AND sf.PosId IS NOT NULL AND sf.PosId <> 0
      AND sf.Pod IS NOT NULL AND sf.Pod <> ''
    GROUP BY sf.SiteId, sf.CalendarDate, sf.Pod
),

-- [WIN #2] Final Aggregation & Sort Weights
AggregatedData AS (
    SELECT
        SiteId, ReportDate, Pod,
        -- Calculate Weight
        CASE 
            WHEN Pod = 'CSO' THEN 1
            WHEN Pod = 'DT' THEN 2
            WHEN Pod = 'FC' THEN 3
            ELSE 99 
        END AS PodWeight,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM PreAggregatedData
    GROUP BY SiteId, ReportDate, Pod
),

-- [WIN #3] Single Pass Grouping Sets
AllRows AS (
    SELECT
        SiteId,
        ReportDate,
        CASE 
            WHEN GROUPING(Pod) = 1 THEN 'Total'
            ELSE Pod 
        END AS Pod,
        
        -- Propagate Weight
        CASE 
            WHEN GROUPING(Pod) = 1 THEN 0 
            ELSE MIN(PodWeight) 
        END AS SortWeight,

        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount,
        
        MAX(SUM(CY_NetAmount)) OVER(PARTITION BY SiteId, ReportDate) AS DailyTotal_Net,
        MAX(SUM(CY_TransactionCount)) OVER(PARTITION BY SiteId, ReportDate) AS DailyTotal_Txn,
        
        MAX(SUM(CY_NetAmount)) OVER() AS GrandTotal_Net,
        MAX(SUM(CY_TransactionCount)) OVER() AS GrandTotal_Txn,

        GROUPING(SiteId) AS IsGrandrow,
        GROUPING(ReportDate) AS IsPodTotalRow,
        GROUPING(Pod) AS IsDailyTotalRow
    FROM AggregatedData
    GROUP BY GROUPING SETS (
        (SiteId, ReportDate, Pod), 
        (SiteId, ReportDate),
        (Pod),
        ()
    )
)

-- Final Projection
SELECT
    ReportDate AS Date,
    SiteId,
    CASE 
        WHEN IsGrandrow = 1 THEN 'Grand Totals'
        ELSE (SELECT SiteName FROM SiteList WHERE SiteId = AllRows.SiteId)
    END AS SiteName,
    CASE
        WHEN IsGrandrow = 1 AND IsPodTotalRow = 1 AND Pod IS NULL THEN 'Total'
        ELSE Pod 
    END AS Pod,

    -- VALUES
    CASE (SELECT SelectedView FROM InputVar)
        WHEN 'D' THEN CY_NetAmount
        WHEN 'G' THEN CAST(CY_TransactionCount AS DECIMAL(18,2))
        WHEN 'A' THEN CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END
        ELSE 0
    END AS Value,

    -- PERCENT TOTAL
    CASE
        WHEN (SELECT SelectedView FROM InputVar) = 'A' THEN 0
        WHEN IsGrandrow = 1 AND Pod = 'Total' THEN 100.0
        WHEN IsGrandrow = 1 THEN 
             CASE (SELECT SelectedView FROM InputVar)
                 WHEN 'D' THEN CASE WHEN GrandTotal_Net = 0 THEN 0 ELSE CY_NetAmount * 100.0 / GrandTotal_Net END
                 WHEN 'G' THEN CASE WHEN GrandTotal_Txn = 0 THEN 0 ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / GrandTotal_Txn END
             END
        WHEN (SELECT SelectedView FROM InputVar) = 'D' THEN
             CASE WHEN DailyTotal_Net = 0 THEN 0 ELSE CY_NetAmount * 100.0 / DailyTotal_Net END
        WHEN (SELECT SelectedView FROM InputVar) = 'G' THEN
             CASE WHEN DailyTotal_Txn = 0 THEN 0 ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / DailyTotal_Txn END
        ELSE 0
    END AS PercentTotal,

    -- YOY INC
    CASE (SELECT SelectedView FROM InputVar)
        WHEN 'D' THEN CASE WHEN PY_NetAmount = 0 THEN 0 ELSE (CY_NetAmount - PY_NetAmount) * 100.0 / PY_NetAmount END
        WHEN 'G' THEN CASE WHEN PY_TransactionCount = 0 THEN 0 ELSE (CAST(CY_TransactionCount AS DECIMAL(18,2)) - PY_TransactionCount) * 100.0 / PY_TransactionCount END
        WHEN 'A' THEN CASE WHEN PY_TransactionCount = 0 OR CY_TransactionCount = 0 THEN 0
                           WHEN (PY_NetAmount / PY_TransactionCount) = 0 THEN 0
                           ELSE ((CY_NetAmount / CY_TransactionCount) - (PY_NetAmount / PY_TransactionCount)) * 100.0 / (PY_NetAmount / PY_TransactionCount) END
        ELSE 0
    END AS PercentInc,

    -- SORT ORDER
    CASE
        WHEN IsGrandrow = 1 THEN -50 + SortWeight
        WHEN IsDailyTotalRow = 1 THEN 0
        ELSE SortWeight
    END AS SortOrder

FROM AllRows
WHERE IsGrandrow = 1 OR ReportDate <= @EndDate
ORDER BY 
    CASE WHEN (IsGrandrow = 1) THEN 0 ELSE 1 END,
    Date ASC,
    SiteName ASC,
    SortOrder ASC
OPTION (RECOMPILE);
