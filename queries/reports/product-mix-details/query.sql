/*
   ===================================================================================
   QUERY: PRODUCT MIX DETAILS - v1.2
   ===================================================================================

   PURPOSE:
   Detail-level product mix report for a single site and date.
   Each row = one product from ProductSalesByOperation joined to ProductMenu.
   Supports Dollar (D) and Quantity (Q) view toggle.
   Supports live search on Code (MIN) and Name (partial match, case-insensitive).
   Supports deep-link via MIN param — adds a 'Selected' row for slideover pre-open.
   Includes a Total row (Code = 'Total') — reflects filtered results.

   OUTPUT FORMAT:
   Columns: RowType, Code, Name, Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Total
   RowType: 'Total' | 'Detail' | 'Selected'

   OUTSYSTEMS PARAMETERS:
   - SiteId (Long Integer)       → Expand Inline = No
   - Date (Date)                 → Expand Inline = No
   - SelectedView (Text)         → Expand Inline = No  ('D' = Dollars, 'Q' = Quantity)
   - SearchText (Text)           → Expand Inline = No  (partial match on Code/Name, empty = show all)
   - MIN (Text)                  → Expand Inline = No  ('0' = no selection, otherwise = selected MIN code)

   FOR SSMS TESTING: See tests/test-ssms.sql
   ===================================================================================
*/

WITH

-- [STEP 1]: InputVar CTE for reliable parameter binding
InputVar AS (SELECT @SelectedView AS Val, @SearchText AS Search, @MIN AS SelectedMIN),

-- [STEP 2]: Aggregate product data by ProductMenu, join for Code/Name
ProductData AS (
    SELECT
        CAST(pm.ProductId AS VARCHAR(50)) AS Code,
        pm.Name,
        -- Dollar amounts (Net)
        SUM(pso.SalesNetAmt) AS Sold_D,
        SUM(pso.PromoNetAmt) AS Promo_D,
        SUM(pso.DiscountNetAmt) AS Discount_D,
        SUM(pso.CrewNetAmt) AS EmpMeals_D,
        SUM(pso.ManagerNetAmt) AS MgrMeals_D,
        SUM(pso.WasteNetAmt) AS Waste_D,
        SUM(pso.TotalNetAmt) AS Total_D,
        -- Quantity amounts
        SUM(pso.SalesQuantity) AS Sold_Q,
        SUM(pso.PromoQuantity) AS Promo_Q,
        SUM(pso.DiscountQuantity) AS Discount_Q,
        SUM(pso.CrewQuantity) AS EmpMeals_Q,
        SUM(pso.ManagerQuantity) AS MgrMeals_Q,
        SUM(pso.WasteQuantity) AS Waste_Q,
        SUM(pso.SalesQuantity) +
        SUM(pso.PromoQuantity) +
        SUM(pso.DiscountQuantity) +
        SUM(pso.CrewQuantity) +
        SUM(pso.ManagerQuantity) +
        SUM(pso.WasteQuantity) AS Total_Q
    FROM {ProductSalesByOperation} pso
    INNER JOIN {ProductMenu} pm ON pso.ProductMenuId = pm.Id
    WHERE pso.SiteId = @SiteId
      AND pso.CalendarDate = @Date
    GROUP BY pm.ProductId, pm.Name
),

-- [STEP 3]: Apply search filter
FilteredData AS (
    SELECT *
    FROM ProductData
    WHERE (SELECT Search FROM InputVar) = ''
       OR Code LIKE '%' + (SELECT Search FROM InputVar) + '%'
       OR Name LIKE '%' + (SELECT Search FROM InputVar) + '%'
),

-- [STEP 4]: Combine Total + Detail + Selected rows
AllRows AS (
    -- Total row (sum of FILTERED results only)
    SELECT
        'Total' AS RowType,
        'Total' AS Code,
        '' AS Name,
        SUM(Sold_D) AS Sold_D, SUM(Promo_D) AS Promo_D, SUM(Discount_D) AS Discount_D,
        SUM(EmpMeals_D) AS EmpMeals_D, SUM(MgrMeals_D) AS MgrMeals_D, SUM(Waste_D) AS Waste_D, SUM(Total_D) AS Total_D,
        SUM(Sold_Q) AS Sold_Q, SUM(Promo_Q) AS Promo_Q, SUM(Discount_Q) AS Discount_Q,
        SUM(EmpMeals_Q) AS EmpMeals_Q, SUM(MgrMeals_Q) AS MgrMeals_Q, SUM(Waste_Q) AS Waste_Q, SUM(Total_Q) AS Total_Q
    FROM FilteredData

    UNION ALL

    -- Detail rows
    SELECT
        'Detail', Code, Name,
        Sold_D, Promo_D, Discount_D, EmpMeals_D, MgrMeals_D, Waste_D, Total_D,
        Sold_Q, Promo_Q, Discount_Q, EmpMeals_Q, MgrMeals_Q, Waste_Q, Total_Q
    FROM FilteredData

    UNION ALL

    -- Selected row (from PRE-SEARCH data, only when MIN != '0')
    SELECT
        'Selected', Code, Name,
        Sold_D, Promo_D, Discount_D, EmpMeals_D, MgrMeals_D, Waste_D, Total_D,
        Sold_Q, Promo_Q, Discount_Q, EmpMeals_Q, MgrMeals_Q, Waste_Q, Total_Q
    FROM ProductData
    WHERE (SELECT SelectedMIN FROM InputVar) <> '0'
      AND Code = (SELECT SelectedMIN FROM InputVar)
)

-- [STEP 5]: Final output with SelectedView toggle
SELECT
    RowType,
    Code,
    Name,

    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ROUND(Sold_D, 2)
        WHEN 'Q' THEN Sold_Q
    END AS Sold,

    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ROUND(Promo_D, 2)
        WHEN 'Q' THEN Promo_Q
    END AS Promo,

    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ROUND(Discount_D, 2)
        WHEN 'Q' THEN Discount_Q
    END AS Discount,

    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ROUND(EmpMeals_D, 2)
        WHEN 'Q' THEN EmpMeals_Q
    END AS EmpMeals,

    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ROUND(MgrMeals_D, 2)
        WHEN 'Q' THEN MgrMeals_Q
    END AS MgrMeals,

    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ROUND(Waste_D, 2)
        WHEN 'Q' THEN Waste_Q
    END AS Waste,

    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ROUND(Total_D, 2)
        WHEN 'Q' THEN Total_Q
    END AS Total

FROM AllRows;
