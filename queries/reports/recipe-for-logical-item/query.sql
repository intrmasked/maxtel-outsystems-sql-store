/*
   ===================================================================================
   QUERY: RECIPE FOR LOGICAL ITEM - v1.0
   ===================================================================================

   PURPOSE:
   Given a LogicalItem (ingredient), find all menu items that use it in their recipe
   and cross-reference against actual sales for a given site and date.
   Powers the "Recipe For Logical" slideover panel showing which products consumed
   a specific ingredient on a given day.

   OUTPUT FORMAT:
   Columns: MIN, MenuItemName, ProductQtyUsed, ItemsPerProduct, QtyUsed

   OUTSYSTEMS PARAMETERS:
   - LogicalItemId (Integer)     → Expand Inline = No
   - SiteId (Integer)            → Expand Inline = No
   - CalendarDate (Date)         → Expand Inline = No
   - ConceptId (Integer)         → Expand Inline = No

   FOR SSMS TESTING: See tests/test-ssms.sql
   ===================================================================================
*/

WITH

-- [STEP 1]: InputVar CTE for reliable parameter binding
InputVar AS (
    SELECT @LogicalItemId AS LogicalItemId, @SiteId AS SiteId,
           @CalendarDate AS CalendarDate, @ConceptId AS ConceptId
),

-- [STEP 2]: Find all menu items that use this logical item in their recipe
--           SUM(BRI.Qty) handles duplicates if a logical item appears multiple times
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
    AND PSBO.CalendarDate = (SELECT CalendarDate FROM InputVar);
