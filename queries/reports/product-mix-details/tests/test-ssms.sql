-- =============================================
-- SSMS Test: Product Mix Details (v1.0)
-- Purpose: Test product mix detail query with DECLARE params
-- Target: SQL Server 2016+
-- =============================================

-- Parameters (change these for testing)
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2026-02-02';
DECLARE @SelectedView VARCHAR(1) = 'D';  -- 'D' = Dollars, 'Q' = Quantity

WITH

-- [STEP 1]: InputVar CTE for reliable parameter binding
InputVar AS (SELECT @SelectedView AS Val),

-- [STEP 2]: Aggregate product data by ProductMenu, join for Code/Name
ProductData AS (
    SELECT
        CAST(pm.ProductId AS VARCHAR(50)) AS Code,
        pm.Name,
        -- Dollar amounts
        SUM(pso.SalesGrossAmt) AS Sold_D,
        SUM(pso.PromoGrossAmt) AS Promo_D,
        SUM(pso.DiscountGrossAmt) AS Discount_D,
        SUM(pso.CrewGrossAmt) AS EmpMeals_D,
        SUM(pso.ManagerGrossAmt) AS MgrMeals_D,
        SUM(pso.WasteGrossAmt) AS Waste_D,
        SUM(pso.TotalGrossAmt) AS Total_D,
        -- Quantity amounts
        SUM(pso.SalesQuantity) AS Sold_Q,
        SUM(pso.PromoQuantity) AS Promo_Q,
        SUM(pso.DiscountQuantity) AS Discount_Q,
        SUM(pso.CrewQuantity) AS EmpMeals_Q,
        SUM(pso.ManagerQuantity) AS MgrMeals_Q,
        SUM(pso.WasteQuantity) AS Waste_Q,
        SUM(pso.TotalQuantitySold) AS Total_Q
    FROM {ProductSalesByOperation} pso
    INNER JOIN {ProductMenu} pm ON pso.ProductMenuId = pm.Id
    WHERE pso.SiteId = @SiteId
      AND pso.CalendarDate = @Date
    GROUP BY pm.ProductId, pm.Name
),

-- [STEP 3]: Combine detail rows + Total row
AllRows AS (
    -- Detail rows
    SELECT
        Code,
        Name,
        Sold_D, Promo_D, Discount_D, EmpMeals_D, MgrMeals_D, Waste_D, Total_D,
        Sold_Q, Promo_Q, Discount_Q, EmpMeals_Q, MgrMeals_Q, Waste_Q, Total_Q
    FROM ProductData

    UNION ALL

    -- Total row (sum of all products)
    SELECT
        'Total',
        '',
        SUM(Sold_D), SUM(Promo_D), SUM(Discount_D), SUM(EmpMeals_D), SUM(MgrMeals_D), SUM(Waste_D), SUM(Total_D),
        SUM(Sold_Q), SUM(Promo_Q), SUM(Discount_Q), SUM(EmpMeals_Q), SUM(MgrMeals_Q), SUM(Waste_Q), SUM(Total_Q)
    FROM ProductData
)

-- [STEP 4]: Final output with SelectedView toggle
SELECT
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
    END AS Total,

    -- Verification columns
    COUNT(*) OVER() AS TotalRows

FROM AllRows
ORDER BY
    CASE WHEN Name = 'Total' THEN 0 ELSE 1 END,
    Name
OPTION (RECOMPILE);
