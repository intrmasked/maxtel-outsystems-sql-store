/*
   ===================================================================================
   QUERY: PRODUCT MIX LIST - v1.0
   ===================================================================================

   PURPOSE:
   Product mix data from ProductSalesByOperation with CashTotal variance from SalesFact.
   Shows Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Total, CashTotal, Variance.

   OUTPUT FORMAT:
   Each row = Site + Date with breakdown
   Site Total = Sum for each site across date range
   Grand Total = Sum for all sites across date range

   OUTSYSTEMS PARAMETERS:
   - SiteIds (Text)      → ⚠️ Expand Inline = YES ⚠️
   - StartDate (Date)    → Expand Inline = No
   - EndDate (Date)      → Expand Inline = No

   FOR SSMS TESTING: See tests/test-ssms.sql
   ===================================================================================
*/

WITH

-- [STEP 1]: Get Site Names
SiteList AS (
    SELECT s.Id AS SiteId, ISNULL(s.DisplayName, s.Name) AS SiteName
    FROM {Site} s
    WHERE s.Id IN (@SiteIds)
),

-- [STEP 2]: Aggregate ProductSalesByOperation by Site/Date
-- Each row is a single product, we SUM to get totals
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
    WHERE pso.SiteId IN (@SiteIds)
      AND pso.CalendarDate BETWEEN @StartDate AND @EndDate
    GROUP BY pso.SiteId, pso.CalendarDate
),

-- [STEP 3]: Calculate CashTotal from SalesFact
-- Matches Cash->ProductSales screen logic
CashTotalData AS (
    SELECT
        sf.SiteId,
        sf.CalendarDate,
        SUM(sf.NetAmount) AS CashTotal
    FROM {SalesFact} sf
    WHERE sf.SiteId IN (@SiteIds)
      AND sf.CalendarDate BETWEEN @StartDate AND @EndDate
      AND sf.DatePeriodDimensionId = 15
      AND sf.SalesFactTypeId = 2  -- QtrHourSalesAndProductMix
      AND sf.ProductSaleTypeId = 1  -- Product Sales
      -- Null out other dimensions
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

-- [STEP 4]: Join ProductMix with CashTotal and calculate Variance
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

-- [STEP 5]: Create all rows with GROUPING SETS (Detail + Site Total + Grand Total)
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
        (SiteId, CalendarDate),  -- Detail rows
        (SiteId),                 -- Site Total
        ()                        -- Grand Total
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
    
    -- Sort Order: Detail rows by Site/Date, Site Total after each site, Grand Total at end
    CASE 
        WHEN IsGrandTotal = 1 THEN 999999
        WHEN IsSiteTotal = 1 THEN 999998
        ELSE 0
    END AS SortOrder

FROM AllRows
ORDER BY 
    CASE WHEN IsGrandTotal = 1 THEN 1 ELSE 0 END,  -- Grand Total last
    SiteId,
    CASE WHEN IsSiteTotal = 1 THEN 1 ELSE 0 END,   -- Site Total after detail rows
    CalendarDate
OPTION (RECOMPILE);
