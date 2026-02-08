-- =============================================
-- SSMS Test: Product Mix List
-- Purpose: Test query with STRING_SPLIT for multi-site support
-- Target: SQL Server 2016+ (for STRING_SPLIT)
-- =============================================

-- Parameters (change these for testing)
DECLARE @SiteIds VARCHAR(100) = '3187';  -- Comma-separated site IDs
DECLARE @StartDate DATE = '2026-02-01';
DECLARE @EndDate DATE = '2026-02-07';

WITH

-- [STEP 1]: Get Site Names (using STRING_SPLIT for SSMS compatibility)
SiteList AS (
    SELECT s.Id AS SiteId, ISNULL(s.DisplayName, s.Name) AS SiteName
    FROM {Site} s
    WHERE s.Id IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
),

-- [STEP 2]: Aggregate ProductSalesByOperation by Site/Date
ProductMixData AS (
    SELECT
        pso.SiteId,
        pso.CalendarDate,
        SUM(pso.SalesGrossAmt) AS Sold,
        SUM(pso.PromoGrossAmt) AS Promo,
        SUM(pso.DiscountGrossAmt) AS Discount,
        SUM(pso.CrewGrossAmt) AS EmpMeals,
        SUM(pso.ManagerGrossAmt) AS MgrMeals,
        SUM(pso.WasteGrossAmt) AS Waste,
        SUM(pso.TotalGrossAmt) AS Total
    FROM {ProductSalesByOperation} pso
    WHERE pso.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
      AND pso.CalendarDate BETWEEN @StartDate AND @EndDate
    GROUP BY pso.SiteId, pso.CalendarDate
),

-- [STEP 3]: Calculate CashTotal from SalesFact
CashTotalData AS (
    SELECT
        sf.SiteId,
        sf.CalendarDate,
        SUM(sf.NetAmount) AS CashTotal
    FROM {SalesFact} sf
    WHERE sf.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
      AND sf.CalendarDate BETWEEN @StartDate AND @EndDate
      AND sf.DatePeriodDimensionId = 15
      AND sf.SalesFactTypeId = 2  -- QtrHourSalesAndProductMix
      AND sf.ProductSaleTypeId = 1  -- Product Sales
      AND sf.ProductMenuId IS NULL
      AND sf.TenderTypeId IS NULL
      AND sf.OperationId IS NULL
      AND sf.OperationKindId IS NULL
      AND sf.SWCCashDrawerId IS NULL
      AND sf.SaleTypeId IS NULL
      AND sf.PosId IS NOT NULL AND sf.PosId <> 0
      AND sf.Pod IS NOT NULL AND sf.Pod <> ''
    GROUP BY sf.SiteId, sf.CalendarDate
),

-- [STEP 4]: Join ProductMix with CashTotal
JoinedData AS (
    SELECT
        pm.SiteId,
        pm.CalendarDate,
        pm.Sold,
        pm.Promo,
        pm.Discount,
        pm.EmpMeals,
        pm.MgrMeals,
        pm.Waste,
        pm.Total,
        ISNULL(ct.CashTotal, 0) AS CashTotal,
        pm.Total - ISNULL(ct.CashTotal, 0) AS Variance
    FROM ProductMixData pm
    LEFT JOIN CashTotalData ct 
        ON pm.SiteId = ct.SiteId 
        AND pm.CalendarDate = ct.CalendarDate
),

-- [STEP 5]: Create all rows with GROUPING SETS
AllRows AS (
    SELECT
        SiteId,
        CalendarDate,
        CASE 
            WHEN GROUPING(CalendarDate) = 1 AND GROUPING(SiteId) = 0 THEN 'Site Total'
            WHEN GROUPING(SiteId) = 1 THEN 'Total'
            ELSE NULL 
        END AS RowType,
        SUM(Sold) AS Sold,
        SUM(Promo) AS Promo,
        SUM(Discount) AS Discount,
        SUM(EmpMeals) AS EmpMeals,
        SUM(MgrMeals) AS MgrMeals,
        SUM(Waste) AS Waste,
        SUM(Total) AS Total,
        SUM(CashTotal) AS CashTotal,
        SUM(Variance) AS Variance,
        GROUPING(SiteId) AS IsGrandTotal,
        GROUPING(CalendarDate) AS IsSiteTotal
    FROM JoinedData
    GROUP BY GROUPING SETS (
        (SiteId, CalendarDate),
        (SiteId),
        ()
    )
)

-- [STEP 6]: Final Output
SELECT
    CASE 
        WHEN IsGrandTotal = 1 THEN 'Total'
        WHEN IsSiteTotal = 1 THEN (SELECT SiteName FROM SiteList WHERE SiteId = AllRows.SiteId) + ' Total'
        ELSE (SELECT SiteName FROM SiteList WHERE SiteId = AllRows.SiteId)
    END AS SiteName,
    
    CASE 
        WHEN IsGrandTotal = 1 OR IsSiteTotal = 1 THEN NULL
        ELSE CalendarDate
    END AS Date,
    
    ROUND(Sold, 2) AS Sold,
    ROUND(Promo, 2) AS Promo,
    ROUND(Discount, 2) AS Discount,
    ROUND(EmpMeals, 2) AS EmpMeals,
    ROUND(MgrMeals, 2) AS MgrMeals,
    ROUND(Waste, 2) AS Waste,
    ROUND(Total, 2) AS Total,
    ROUND(CashTotal, 2) AS CashTotal,
    ROUND(Variance, 2) AS Variance,
    
    CASE 
        WHEN IsGrandTotal = 1 THEN 999999
        WHEN IsSiteTotal = 1 THEN 999998
        ELSE 0
    END AS SortOrder,
    
    -- Verification columns
    COUNT(*) OVER() AS TotalRows

FROM AllRows
ORDER BY 
    CASE WHEN IsGrandTotal = 1 THEN 1 ELSE 0 END,
    SiteId,
    CASE WHEN IsSiteTotal = 1 THEN 1 ELSE 0 END,
    CalendarDate
OPTION (RECOMPILE);
