-- =============================================
-- Test: Recipe For Logical Item — SSMS Sandbox Version
-- Purpose: Full query with DECLARE params for SSMS testing
-- Created: 2026-03-22
-- =============================================

DECLARE @LogicalItemId INT = 1;        -- Change to a valid LogicalItem.Id
DECLARE @SiteId INT = 3187;
DECLARE @CalendarDate DATE = '2026-03-20';
DECLARE @ConceptId INT = 1;            -- Change to valid ConceptId

WITH

-- [STEP 1]: InputVar CTE for reliable parameter binding
InputVar AS (
    SELECT @LogicalItemId AS LogicalItemId, @SiteId AS SiteId,
           @CalendarDate AS CalendarDate, @ConceptId AS ConceptId
),

-- [STEP 2]: Find all menu items that use this logical item in their recipe
RecipeItems AS (
    SELECT
        BM.[MIN],
        BM.LONGNAME AS MenuItemName,
        PM.Id AS ProductMenuId,
        SUM(BRI.Qty) AS ItemsPerProduct
    FROM {BO_RawIngredient} BRI
    INNER JOIN {BO_Recipe} BR
        ON BRI.BORecipeId = BR.Id
    INNER JOIN {BO_MenuItem} BM
        ON BR.BOMenuItemId = BM.Refkey
    INNER JOIN {ProductMenu} PM
        ON BM.[MIN] = PM.ProductId
        AND PM.ConceptId = (SELECT ConceptId FROM InputVar)
    INNER JOIN {LogicalItem} LI
        ON BRI.BORawItemId = LI.BO_RawItemId
        AND LI.ConceptId = (SELECT ConceptId FROM InputVar)
    WHERE LI.Id = (SELECT LogicalItemId FROM InputVar)
      AND BR.IsDeleted = 0
      AND BRI.IsDeleted = 0
      AND BM.ConceptId = (SELECT ConceptId FROM InputVar)
    GROUP BY BM.[MIN], BM.LONGNAME, PM.Id
)

-- [STEP 3]: Left join to sales data and calculate QtyUsed
SELECT
    ri.[MIN],
    ri.MenuItemName,
    PSBO.SalesQuantity AS ProductQtyUsed,
    ri.ItemsPerProduct,
    CASE
        WHEN PSBO.SalesQuantity IS NULL THEN NULL
        ELSE PSBO.SalesQuantity * ri.ItemsPerProduct
    END AS QtyUsed
FROM RecipeItems ri
LEFT JOIN {ProductSalesByOperation} PSBO
    ON ri.ProductMenuId = PSBO.ProductMenuId
    AND PSBO.SiteId = (SELECT SiteId FROM InputVar)
    AND PSBO.CalendarDate = (SELECT CalendarDate FROM InputVar)
ORDER BY
    CASE WHEN PSBO.SalesQuantity IS NULL THEN 1 ELSE 0 END,
    PSBO.SalesQuantity DESC;
