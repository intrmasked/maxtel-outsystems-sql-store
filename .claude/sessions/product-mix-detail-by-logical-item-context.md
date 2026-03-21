# Session: Product Mix Detail by Logical Item - 2026-03-21

## Original Story/Requirements
Detail-level product mix report by logical item. Same concept as product-mix-details but uses LogicalItem/LogicalItemUsage tables instead of ProductMenu/ProductSalesByOperation. User provided UI screenshot showing expected output layout.

**UI Screenshot confirms:**
- Columns: WRIN, Description, Sold, Promo, Discount, Emp Meals, Mgr Meals, Waste, Total
- Total row appears FIRST (top of table)
- No Refund column visible
- Dollar/Quantity view toggle (dropdown)
- Paginated (e.g. "1 to 5 of 38 items")

## Status
- [ ] Complete / [ ] In Testing / [X] In Progress
- Current step: v1.1 query matches UI screenshot, awaiting user feedback/testing
- Incomplete items: User to confirm output, test in sandbox

## Version History
| Version | Changes |
|---------|---------|
| v1.0 | Initial scaffold with Refund column, WrinNumber/ItemName column names |
| v1.1 | Matched to UI screenshot: removed Refund, renamed to WRIN/Description, added SortOrder for Total-first ordering |

## Tables Documentation Created
- `database-context/tables/LogicalItem/` - **NEW** - Logical item master (WrinNumber, ItemName, ConceptId)
- `database-context/tables/LogicalItemUsage/` - **NEW** - Daily usage data per logical item per site (Net amounts + quantities)

## Queries Created
- `queries/reports/product-mix-detail-by-logical-item/` - Status: in-progress
  - Purpose: Detail product mix by logical item with Dollar/Quantity toggle
  - Tables used: LogicalItemUsage, LogicalItem
  - Output: WRIN, Description, Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Total, SortOrder

## Key Decisions
- **Modelled after product-mix-details**: Same D/Q toggle pattern, same Total row via UNION ALL
- **No Refund column**: Screenshot confirms UI doesn't show Refund — excluded from output (data still in table if needed later)
- **Column names match UI**: WRIN, Description (not WrinNumber/ItemName), Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Total
- **Total row first**: SortOrder = 0 for Total, SortOrder = 1 for detail rows. ORDER BY SortOrder, Description.
- **Total = sum of all ops (excl Refund)**: Sales + Promo + Discount + Crew + Manager + Waste
- **InputVar CTE**: Used for @SelectedView parameter binding (OutSystems quirk)

## Git Commits
- `d91d81b` — feat: Initial query scaffold + table docs
- `de70915` — fix: Match output to UI screenshot (removed Refund, renamed columns, added SortOrder)

## Next Steps
1. User confirms output matches expectations
2. Test in sandbox
3. Iterate based on feedback

## Notes for Next Session
- LogicalItemUsage HAS RefundNetAmt/RefundQty columns — excluded from output per UI but available if needed
- Module: Sales_UI (Stock section) for both LogicalItem and LogicalItemUsage
- Similar structure to product-mix-details — refer to that session context for patterns

## Quick Resume
To continue:
1. Read table docs: `database-context/tables/LogicalItem/README.md` and `LogicalItemUsage/README.md`
2. Check query: `queries/reports/product-mix-detail-by-logical-item/query.sql`
3. Continue from: User feedback on v1.1 output
