/*
   ===================================================================================
   QUERY: RECIPE FOR LOGICAL ITEM - v3.0
   ===================================================================================

   PURPOSE:
   Given a WRIN (ingredient), find all menu items that use it in their recipe
   and cross-reference against actual sales for a given site and date.
   Powers the "Recipe For Logical" slideover panel.

   PATHS:
   - Path A (Direct): BO_RawIngredient(WRIN) → BO_Recipe → BO_MenuItem
   - Path B (Combo):  BO_Recipe → BO_MenuIngredient → BO_MenuItem → BO_Recipe → BO_RawIngredient(WRIN)

   OUTSYSTEMS PARAMETERS:
   - WRIN (Text)                 → Expand Inline = No
   - SiteId (Integer)            → Expand Inline = No
   - CalendarDate (Date)         → Expand Inline = No
   - ConceptId (Integer)         → Expand Inline = No

   FOR SSMS TESTING: See tests/test-ssms.sql
   ===================================================================================
*/

WITH

InputVar AS (
    SELECT @WRIN AS WRIN, @SiteId AS SiteId,
           @CalendarDate AS CalendarDate, @ConceptId AS ConceptId
),

-- Path A: Direct — product directly contains this WRIN
-- Path B: Combo  — product is a combo whose sub-item contains this WRIN
RecipeItems AS (
    -- Path A
    SELECT
        CAST(BM.[MIN] AS VARCHAR(50)) AS [MIN],
        BM.LONGNAME AS MenuItemName,
        PM.Id AS ProductMenuId,
        SUM(BRI.Qty) AS ItemsPerProduct
    FROM {BO_RawIngredient} BRI
    INNER JOIN {BO_Recipe} BR       ON BRI.BORecipeId = BR.Id
    INNER JOIN {BO_MenuItem} BM     ON BR.BOMenuItemId = BM.Refkey
    INNER JOIN {ProductMenu} PM     ON BM.[MIN] = PM.ProductId
                                    AND PM.ConceptId = (SELECT ConceptId FROM InputVar)
    WHERE BRI.WRIN = (SELECT WRIN FROM InputVar)
      AND BRI.IsDeleted = 0
      AND BR.IsDeleted = 0
      AND BM.ConceptId = (SELECT ConceptId FROM InputVar)
    GROUP BY BM.[MIN], BM.LONGNAME, PM.Id

    UNION ALL

    -- Path B
    SELECT
        CAST(BM.[MIN] AS VARCHAR(50)) AS [MIN],
        BM.LONGNAME AS MenuItemName,
        PM.Id AS ProductMenuId,
        SUM(BMI.Qty * BRI2.Qty) AS ItemsPerProduct
    FROM {BO_MenuItem} BM
    INNER JOIN {BO_Recipe} BR       ON BR.BOMenuItemId = BM.Refkey
    INNER JOIN {BO_MenuIngredient} BMI ON BMI.BORecipeId = BR.Id
    INNER JOIN {BO_MenuItem} BM2    ON BMI.MIN = BM2.[MIN]
                                    AND BM2.ConceptId = (SELECT ConceptId FROM InputVar)
    INNER JOIN {BO_Recipe} BR2      ON BR2.BOMenuItemId = BM2.Refkey
    INNER JOIN {BO_RawIngredient} BRI2 ON BRI2.BORecipeId = BR2.Id
    INNER JOIN {ProductMenu} PM     ON BM.[MIN] = PM.ProductId
                                    AND PM.ConceptId = (SELECT ConceptId FROM InputVar)
    WHERE BRI2.WRIN = (SELECT WRIN FROM InputVar)
      AND BRI2.IsDeleted = 0
      AND BR.IsDeleted = 0
      AND BMI.IsDeleted = 0
      AND BR2.IsDeleted = 0
      AND BM.ConceptId = (SELECT ConceptId FROM InputVar)
    GROUP BY BM.[MIN], BM.LONGNAME, PM.Id
),

-- Merge both paths (same product may appear in both)
AggRecipe AS (
    SELECT [MIN], MenuItemName, ProductMenuId,
           SUM(ItemsPerProduct) AS ItemsPerProduct
    FROM RecipeItems
    GROUP BY [MIN], MenuItemName, ProductMenuId
),

-- Left join to sales
WithSales AS (
    SELECT
        ar.[MIN],
        ar.MenuItemName,
        PSBO.SalesQuantity AS ProductQtyUsed,
        ar.ItemsPerProduct,
        CASE
            WHEN PSBO.SalesQuantity IS NULL THEN NULL
            ELSE PSBO.SalesQuantity * ar.ItemsPerProduct
        END AS QtyUsed
    FROM AggRecipe ar
    LEFT JOIN {ProductSalesByOperation} PSBO
        ON ar.ProductMenuId = PSBO.ProductMenuId
        AND PSBO.SiteId = (SELECT SiteId FROM InputVar)
        AND PSBO.CalendarDate = (SELECT CalendarDate FROM InputVar)
)

-- Data rows + Totals row
SELECT [MIN], MenuItemName, ProductQtyUsed, ItemsPerProduct, QtyUsed
FROM WithSales

UNION ALL

SELECT 'Total', '', NULL, NULL, SUM(QtyUsed)
FROM WithSales;
