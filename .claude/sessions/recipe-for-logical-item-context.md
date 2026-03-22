# Session: Recipe For Logical Item - 2026-03-22

## Original Story/Requirements
SQL query for OutSystems aggregate `GetRecipeForLogical` inside the `NewPos6` module, screen `ProductMixLogicalItemRecipie`. Given a LogicalItem (ingredient), find all menu items that use it in their recipe and cross-reference against actual sales for a given site and date. Powers a slideover panel called "Recipe For Logical".

**Key requirements:**
- LEFT JOIN on ProductSalesByOperation — products with no sales must still appear (NULL)
- QtyUsed = NULL when no sales (not 0) — intentional business requirement
- SUM(BRI.Qty) to handle duplicates if ingredient appears multiple times in a recipe
- No ORDER BY in production query (OutSystems handles sorting)

## Status
- [ ] Complete / [ ] In Testing / [X] In Progress
- Current step: v1.0 query scaffolded with all table docs, ready for user testing
- Incomplete items: User to test with real data, verify join chain produces correct results

## Tables Documentation Created
- `database-context/tables/BO_RawIngredient/` - **NEW** - Recipe ingredient records
- `database-context/tables/BO_Recipe/` - **NEW** - Recipe definitions

## Tables Documentation Used (Existing)
- `database-context/tables/BO_MenuItem/` - Menu item master
- `database-context/tables/ProductMenu/` - Product menu catalog
- `database-context/tables/ProductSalesByOperation/` - Actual sales data
- `database-context/tables/LogicalItem/` - Logical item master

## Queries Created
- `queries/reports/recipe-for-logical-item/` - Status: in-progress
  - Purpose: Recipe lookup for logical item with sales cross-reference
  - Tables used: BO_RawIngredient, BO_Recipe, BO_MenuItem, ProductMenu, ProductSalesByOperation, LogicalItem
  - Output: MIN, MenuItemName, ProductQtyUsed, ItemsPerProduct, QtyUsed

## Key Decisions
- **SUM(BRI.Qty)**: Handles case where a logical item appears multiple times in one recipe — sums the quantities
- **NULL not 0 for QtyUsed**: CASE WHEN instead of ISNULL — per user requirement, NULL means no sales
- **LEFT JOIN on PSBO**: Products in recipe but with no sales still appear in results
- **NULLS LAST in test only**: SQL Server workaround `CASE WHEN IS NULL THEN 1 ELSE 0 END` — only in test query, production has no ORDER BY
- **InputVar CTE**: Binds all 4 parameters (OutSystems Lazy Parser fix)
- **ConceptId filter**: Applied on ProductMenu join, LogicalItem join, AND BO_MenuItem WHERE clause

## Join Chain
```
LogicalItem.BO_RawItemId = BO_RawIngredient.BORawItemId
BO_RawIngredient.BORecipeId = BO_Recipe.Id
BO_Recipe.BOMenuItemId = BO_MenuItem.Refkey
BO_MenuItem.MIN = ProductMenu.ProductId (+ ConceptId)
ProductMenu.Id = ProductSalesByOperation.ProductMenuId (LEFT JOIN + SiteId + CalendarDate)
```

## Next Steps
1. User tests with real LogicalItemId and site data
2. Verify join chain produces correct menu items
3. Verify sales cross-reference works
4. Iterate based on feedback

## Quick Resume
To continue:
1. Read table docs: `database-context/tables/BO_RawIngredient/README.md` and `BO_Recipe/README.md`
2. Check query: `queries/reports/recipe-for-logical-item/query.sql`
3. Continue from: User testing with real data
