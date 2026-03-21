/*
   ===================================================================================
   QUERY: PRODUCT MIX DETAIL BY LOGICAL ITEM - v1.1
   ===================================================================================

   PURPOSE:
   Detail-level product mix report by logical item for a single site and date.
   Each row = one logical item from LogicalItemUsage joined to LogicalItem.
   Supports Dollar (D) and Quantity (Q) view toggle.
   Total row appears first (SortOrder = 0), detail rows after (SortOrder = 1).

   OUTPUT FORMAT:
   Columns: WRIN, Description, Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Total, SortOrder
   Total row  = WRIN = '', Description = 'Total', SortOrder = 0
   Detail rows = SortOrder = 1

   OUTSYSTEMS PARAMETERS:
   - SiteId (Long Integer)       → Expand Inline = No
   - Date (Date)                 → Expand Inline = No
   - SelectedView (Text)         → Expand Inline = No  ('D' = Dollars, 'Q' = Quantity)

   FOR SSMS TESTING: See tests/test-ssms.sql
   ===================================================================================
*/

WITH

-- [STEP 1]: InputVar CTE for reliable parameter binding
InputVar AS (SELECT @SelectedView AS Val),

-- [STEP 2]: Aggregate usage data by LogicalItem, join for WrinNumber/ItemName
ItemData AS (
    SELECT
        li.WrinNumber,
        li.ItemName,
        -- Dollar amounts (Net)
        SUM(liu.SalesNetAmt) AS Sold_D,
        SUM(liu.PromoNetAmt) AS Promo_D,
        SUM(liu.DiscountNetAmt) AS Discount_D,
        SUM(liu.CrewNetAmt) AS EmpMeals_D,
        SUM(liu.ManagerNetAmt) AS MgrMeals_D,
        SUM(liu.WasteNetAmt) AS Waste_D,
        SUM(liu.SalesNetAmt) +
        SUM(liu.PromoNetAmt) +
        SUM(liu.DiscountNetAmt) +
        SUM(liu.CrewNetAmt) +
        SUM(liu.ManagerNetAmt) +
        SUM(liu.WasteNetAmt) AS Total_D,
        -- Quantity amounts
        SUM(liu.SalesQty) AS Sold_Q,
        SUM(liu.PromoQty) AS Promo_Q,
        SUM(liu.DiscountQty) AS Discount_Q,
        SUM(liu.CrewQty) AS EmpMeals_Q,
        SUM(liu.ManagerQty) AS MgrMeals_Q,
        SUM(liu.WasteQty) AS Waste_Q,
        SUM(liu.SalesQty) +
        SUM(liu.PromoQty) +
        SUM(liu.DiscountQty) +
        SUM(liu.CrewQty) +
        SUM(liu.ManagerQty) +
        SUM(liu.WasteQty) AS Total_Q
    FROM {LogicalItemUsage} liu
    INNER JOIN {LogicalItem} li ON liu.LogicalItemId = li.Id
    WHERE liu.SiteId = @SiteId
      AND liu.CalendarDate = @Date
    GROUP BY li.WrinNumber, li.ItemName
),

-- [STEP 3]: Combine Total row (first) + detail rows
AllRows AS (
    -- Total row (SortOrder = 0 → appears first)
    SELECT
        '' AS WRIN,
        'Total' AS Description,
        SUM(Sold_D) AS Sold_D, SUM(Promo_D) AS Promo_D, SUM(Discount_D) AS Discount_D,
        SUM(EmpMeals_D) AS EmpMeals_D, SUM(MgrMeals_D) AS MgrMeals_D, SUM(Waste_D) AS Waste_D, SUM(Total_D) AS Total_D,
        SUM(Sold_Q) AS Sold_Q, SUM(Promo_Q) AS Promo_Q, SUM(Discount_Q) AS Discount_Q,
        SUM(EmpMeals_Q) AS EmpMeals_Q, SUM(MgrMeals_Q) AS MgrMeals_Q, SUM(Waste_Q) AS Waste_Q, SUM(Total_Q) AS Total_Q,
        0 AS SortOrder
    FROM ItemData

    UNION ALL

    -- Detail rows (SortOrder = 1)
    SELECT
        WrinNumber, ItemName,
        Sold_D, Promo_D, Discount_D, EmpMeals_D, MgrMeals_D, Waste_D, Total_D,
        Sold_Q, Promo_Q, Discount_Q, EmpMeals_Q, MgrMeals_Q, Waste_Q, Total_Q,
        1
    FROM ItemData
)

-- [STEP 4]: Final output with SelectedView toggle
SELECT
    WRIN,
    Description,

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
    END AS Total,

    SortOrder

FROM AllRows
ORDER BY SortOrder, Description;
