-- =============================================
-- ARCHIVED: Site Total Logic
-- Purpose: Site Total row per site (commented out from main query)
-- To restore: Add this GROUPING SET back to AllRows CTE
-- =============================================

-- This was the original GROUPING SETS that included Site Total:
/*
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
        (SiteId),                 -- Site Total  <-- THIS LINE ADDS SITE TOTAL
        ()                        -- Grand Total
    )
)
*/

-- To add Site Total back, modify the GROUPING SETS in query.sql from:
--     GROUP BY GROUPING SETS (
--         (SiteId, CalendarDate),
--         ()
--     )
-- 
-- To:
--     GROUP BY GROUPING SETS (
--         (SiteId, CalendarDate),
--         (SiteId),              -- <-- Add this line
--         ()
--     )
--
-- And update the SiteName CASE logic:
--     CASE 
--         WHEN IsGrandTotal = 1 THEN 'Total'
--         WHEN IsSiteTotal = 1 THEN (SELECT SiteName FROM SiteList WHERE SiteId = AllRows.SiteId) + ' Total'
--         ELSE (SELECT SiteName FROM SiteList WHERE SiteId = AllRows.SiteId)
--     END AS SiteName
