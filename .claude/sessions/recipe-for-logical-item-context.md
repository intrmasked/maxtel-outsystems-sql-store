# Session: Recipe For Logical Item - 2026-03-22

## Original Story/Requirements
SQL query for the "Recipe For Logical" slideover (Section 9 of the Product Mix by Logical Item mini-spec, Feature ID 2.1). Given a WRIN (ingredient identifier), find all menu items that use it in their recipe — both directly (Path A) and via combo sub-items (Path B) — and cross-reference against actual sales for a given site and date.

**Key requirements from spec:**
- Two ingredient paths: Path A (direct raw ingredients) + Path B (combo sub-items, one level deep)
- LEFT JOIN on ProductSalesByOperation — products with no sales must still appear (blank Qty columns)
- QtyUsed = NULL when no sales (not 0) — intentional business requirement
- Totals row at top summing QtyUsed across all rows
- Path B multiplier: BMI.Qty × BRI2.Qty
- No ORDER BY in production query (OutSystems handles sorting)

## Status
- [ ] Complete / [ ] In Testing / [X] In Progress
- Current step: v3.0 query built — WRIN-based, Path A + Path B + Totals row, ready for user testing
- Incomplete items: User to test with real data

## Tables Documentation Created
- `database-context/tables/BO_RawIngredient/` - **EXISTING** (created in v1.0)
- `database-context/tables/BO_Recipe/` - **EXISTING** (created in v1.0)
- `database-context/tables/BO_MenuIngredient/` - **NEW** (created in v2.0) - Combo sub-item records

## Tables Documentation Used (Existing)
- `database-context/tables/BO_MenuItem/` - Menu item master
- `database-context/tables/ProductMenu/` - Product menu catalog
- `database-context/tables/ProductSalesByOperation/` - Actual sales data

## Queries Created
- `queries/reports/recipe-for-logical-item/` - Status: in-progress (v3.0)
  - Purpose: Recipe lookup by WRIN with sales cross-reference (both paths)
  - Tables used: BO_RawIngredient, BO_Recipe, BO_MenuItem, BO_MenuIngredient, ProductMenu, ProductSalesByOperation
  - Output: MIN, MenuItemName, ProductQtyUsed, ItemsPerProduct, QtyUsed + Totals row

## Key Decisions
- **v3.0: WRIN as identifier** — Dropped LogicalItemId / LogicalItem table entirely. BO_RawIngredient.WRIN is the direct filter. Much simpler join chain.
- **NULL not 0 for QtyUsed**: CASE WHEN — per user requirement, NULL means no sales
- **LEFT JOIN on PSBO**: Products in recipe but with no sales still appear
- **InputVar CTE**: Binds all 4 parameters (OutSystems Lazy Parser fix)
- **ConceptId**: Still needed — filters BO_MenuItem and ProductMenu
- **UNION ALL for Path A + B**: Both paths combined, then aggregated
- **Totals row**: UNION ALL with MIN='Total', sums QtyUsed

## Version History
- **v1.0** (2026-03-22): Initial scaffold — Path A only, LogicalItemId-based
- **v2.0** (2026-03-22): Added Path B (combo sub-items), Totals row, still LogicalItemId-based
- **v3.0** (2026-03-22): Simplified — switched to WRIN as identifier, dropped LogicalItem table join

## Next Steps
1. User tests with real WRIN and site data
2. Verify Path A (direct) produces correct menu items
3. Verify Path B (combo) produces correct menu items
4. Verify sales cross-reference and totals row
5. Iterate based on feedback

## Quick Resume
To continue:
1. Check query: `queries/reports/recipe-for-logical-item/query.sql`
2. Test query: `queries/reports/recipe-for-logical-item/tests/test-ssms.sql`
3. Continue from: User testing with real data
