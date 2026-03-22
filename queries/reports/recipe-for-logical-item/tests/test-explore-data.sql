-- =============================================
-- Test: Explore raw data to find testable values
-- Purpose: Find valid WRIN, SiteId, CalendarDate, ConceptId combos
-- =============================================

SELECT TOP 20
    BRI.WRIN,
    BM.ConceptId,
    CAST(BM.[MIN] AS VARCHAR(50)) AS [MIN],
    BM.LONGNAME AS MenuItemName,
    BRI.Qty,
    BR.IsCombo,
    PM.Id AS ProductMenuId,
    PSBO.SiteId,
    PSBO.CalendarDate,
    PSBO.SalesQuantity
FROM {BO_RawIngredient} BRI
INNER JOIN {BO_Recipe} BR       ON BRI.BORecipeId = BR.Id
INNER JOIN {BO_MenuItem} BM     ON BR.BOMenuItemId = BM.Refkey
INNER JOIN {ProductMenu} PM     ON BM.[MIN] = PM.ProductId
                                AND PM.ConceptId = BM.ConceptId
INNER JOIN {ProductSalesByOperation} PSBO
    ON PM.Id = PSBO.ProductMenuId
WHERE BRI.IsDeleted = 0
  AND BR.IsDeleted = 0
  AND PSBO.SalesQuantity > 0
ORDER BY PSBO.CalendarDate DESC, BRI.WRIN;
