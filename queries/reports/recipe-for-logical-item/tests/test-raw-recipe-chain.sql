-- =============================================
-- Test: Run the actual Path A query logic — does it find MIN 5170?
-- =============================================

DECLARE @WRIN VARCHAR(50) = '90000056';
DECLARE @ConceptId INT = 129;

WITH

InputVar AS (
    SELECT @WRIN AS WRIN, @ConceptId AS ConceptId
),

TargetRawItems AS (
    SELECT LI.BO_RawItemId
    FROM {LogicalItem} LI
    WHERE LI.WrinNumber = (SELECT WRIN FROM InputVar)
      AND LI.ConceptId = (SELECT ConceptId FROM InputVar)
)

SELECT
    CAST(BM.[MIN] AS VARCHAR(50)) AS [MIN],
    BM.LONGNAME AS MenuItemName,
    PM.Id AS ProductMenuId,
    SUM(BRI.Qty) AS ItemsPerProduct
FROM {BO_RawIngredient} BRI
INNER JOIN TargetRawItems TRI   ON BRI.BORawItemId = TRI.BO_RawItemId
INNER JOIN {BO_Recipe} BR       ON BRI.BORecipeId = BR.Id
INNER JOIN {BO_MenuItem} BM     ON BR.BOMenuItemId = BM.Refkey
INNER JOIN {ProductMenu} PM     ON BM.[MIN] = PM.ProductId
                                AND PM.ConceptId = (SELECT ConceptId FROM InputVar)
WHERE BRI.IsDeleted = 0
  AND BR.IsDeleted = 0
  AND BM.ConceptId = (SELECT ConceptId FROM InputVar)
GROUP BY BM.[MIN], BM.LONGNAME, PM.Id;
