-- =============================================
-- Test: Recipe For Logical Item — SSMS Sandbox Version
-- Version: v3.0 — WRIN-based, Path A + Path B
-- Created: 2026-03-22
-- =============================================

DECLARE @WRIN VARCHAR(50) = '1234';     -- Change to a valid WRIN
DECLARE @SiteId INT = 3187;
DECLARE @CalendarDate DATE = '2026-03-20';
DECLARE @ConceptId INT = 1;

WITH

InputVar AS (
    SELECT @WRIN AS WRIN, @SiteId AS SiteId,
           @CalendarDate AS CalendarDate, @ConceptId AS ConceptId
),

RecipeItems AS (
    -- Path A: Direct
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

    -- Path B: Combo (one level deep)
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

AggRecipe AS (
    SELECT [MIN], MenuItemName, ProductMenuId,
           SUM(ItemsPerProduct) AS ItemsPerProduct
    FROM RecipeItems
    GROUP BY [MIN], MenuItemName, ProductMenuId
),

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

SELECT [MIN], MenuItemName, ProductQtyUsed, ItemsPerProduct, QtyUsed,
       1 AS SortGroup,
       CASE WHEN ProductQtyUsed IS NULL THEN 1 ELSE 0 END AS NullSort,
       ISNULL(ProductQtyUsed, 0) AS SortQty
FROM WithSales

UNION ALL

SELECT 'Total', '', NULL, NULL, SUM(QtyUsed),
       0, 0, 0
FROM WithSales

ORDER BY SortGroup, NullSort, SortQty DESC;
