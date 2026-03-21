# Session: Product Mix Detail by Logical Item - 2026-03-21

## Original Story/Requirements
Detail-level product mix report by logical item. Same concept as product-mix-details but uses LogicalItem/LogicalItemUsage tables instead of ProductMenu/ProductSalesByOperation. User will provide more information as we go.

## Status
- [ ] Complete / [ ] In Testing / [X] In Progress
- Current step: Initial query scaffolded, table docs created, awaiting user feedback
- Incomplete items: User to provide additional requirements/confirm structure

## Tables Documentation Created
- `database-context/tables/LogicalItem/` - **NEW** - Logical item master (WrinNumber, ItemName)
- `database-context/tables/LogicalItemUsage/` - **NEW** - Daily usage data per logical item per site

## Queries Created
- `queries/reports/product-mix-detail-by-logical-item/` - Status: in-progress
  - Purpose: Detail product mix by logical item with Dollar/Quantity toggle
  - Tables used: LogicalItemUsage, LogicalItem
  - Output: WrinNumber, ItemName, Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Refund, Total

## Key Decisions
- **Modelled after product-mix-details**: Same D/Q toggle pattern, same Total row via UNION ALL
- **No Refund column**: Screenshot confirms UI doesn't show Refund — excluded from output (data still in table if needed later)
- **Column names match UI**: WRIN, Description (not WrinNumber/ItemName), Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Total
- **Total row first**: SortOrder = 0 for Total, SortOrder = 1 for detail rows. ORDER BY SortOrder, Description.
- **Total = sum of all ops (excl Refund)**: Sales + Promo + Discount + Crew + Manager + Waste
- **InputVar CTE**: Used for @SelectedView parameter binding (OutSystems quirk)

## Next Steps
1. User provides additional requirements/feedback
2. Test in sandbox
3. Iterate based on feedback

## Quick Resume
To continue:
1. Read table docs: `database-context/tables/LogicalItem/README.md` and `LogicalItemUsage/README.md`
2. Check query: `queries/reports/product-mix-detail-by-logical-item/query.sql`
3. Continue from: Awaiting user feedback on initial structure
