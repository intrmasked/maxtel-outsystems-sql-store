-- =============================================
-- Test: Product Mix Detail by Logical Item — SSMS Sandbox Version
-- Purpose: Full query with DECLARE params for SSMS testing
-- Created: 2026-03-21
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2026-03-20';
DECLARE @SelectedView VARCHAR(1) = 'D';

WITH

-- [STEP 1]: InputVar CTE for reliable parameter binding
InputVar AS (SELECT @SelectedView AS Val),

-- [STEP 2]: Aggregate usage data by LogicalItem
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
        SUM(liu.RefundNetAmt) AS Refund_D,
        SUM(liu.SalesNetAmt) +
        SUM(liu.PromoNetAmt) +
        SUM(liu.DiscountNetAmt) +
        SUM(liu.CrewNetAmt) +
        SUM(liu.ManagerNetAmt) +
        SUM(liu.WasteNetAmt) +
        SUM(liu.RefundNetAmt) AS Total_D,
        -- Quantity amounts
        SUM(liu.SalesQty) AS Sold_Q,
        SUM(liu.PromoQty) AS Promo_Q,
        SUM(liu.DiscountQty) AS Discount_Q,
        SUM(liu.CrewQty) AS EmpMeals_Q,
        SUM(liu.ManagerQty) AS MgrMeals_Q,
        SUM(liu.WasteQty) AS Waste_Q,
        SUM(liu.RefundQty) AS Refund_Q,
        SUM(liu.SalesQty) +
        SUM(liu.PromoQty) +
        SUM(liu.DiscountQty) +
        SUM(liu.CrewQty) +
        SUM(liu.ManagerQty) +
        SUM(liu.WasteQty) +
        SUM(liu.RefundQty) AS Total_Q
    FROM {LogicalItemUsage} liu
    INNER JOIN {LogicalItem} li ON liu.LogicalItemId = li.Id
    WHERE liu.SiteId = @SiteId
      AND liu.CalendarDate = @Date
    GROUP BY li.WrinNumber, li.ItemName
),

-- [STEP 3]: Combine detail rows + Total row
AllRows AS (
    SELECT
        WrinNumber, ItemName,
        Sold_D, Promo_D, Discount_D, EmpMeals_D, MgrMeals_D, Waste_D, Refund_D, Total_D,
        Sold_Q, Promo_Q, Discount_Q, EmpMeals_Q, MgrMeals_Q, Waste_Q, Refund_Q, Total_Q
    FROM ItemData

    UNION ALL

    SELECT
        'Total', '',
        SUM(Sold_D), SUM(Promo_D), SUM(Discount_D), SUM(EmpMeals_D), SUM(MgrMeals_D), SUM(Waste_D), SUM(Refund_D), SUM(Total_D),
        SUM(Sold_Q), SUM(Promo_Q), SUM(Discount_Q), SUM(EmpMeals_Q), SUM(MgrMeals_Q), SUM(Waste_Q), SUM(Refund_Q), SUM(Total_Q)
    FROM ItemData
)

-- [STEP 4]: Final output with SelectedView toggle
SELECT
    WrinNumber,
    ItemName,

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
        WHEN 'D' THEN ROUND(Refund_D, 2)
        WHEN 'Q' THEN Refund_Q
    END AS Refund,

    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ROUND(Total_D, 2)
        WHEN 'Q' THEN Total_Q
    END AS Total

FROM AllRows
ORDER BY ItemName;
