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
- Current step: v1.2 — removed SortOrder from production query (OutSystems handles sorting)
- Incomplete items: User to test with real site data

## Version History
| Version | Changes |
|---------|---------|
| v1.0 | Initial scaffold with Refund column, WrinNumber/ItemName column names |
| v1.1 | Matched to UI screenshot: removed Refund, renamed to WRIN/Description, added SortOrder |
| v1.2 | Removed SortOrder + ORDER BY from production query — OutSystems handles sorting. Test queries keep SortOrder. |

## Data Exploration Results
- **206** logical items across DB
- **34** sites with data
- **6** days of data (2026-03-16 to 2026-03-21)
- **23,738** total usage rows
- WRIN range: 90000002 → 90013500
- Item names: APPLE SLICES → WRAP MULTI MCWRAP

## Tables Documentation Created
- `database-context/tables/LogicalItem/` - **NEW** - Logical item master (WrinNumber, ItemName, ConceptId)
- `database-context/tables/LogicalItemUsage/` - **NEW** - Daily usage data per logical item per site (Net amounts + quantities)

## Queries Created
- `queries/reports/product-mix-detail-by-logical-item/` - Status: in-progress
  - Purpose: Detail product mix by logical item with Dollar/Quantity toggle
  - Tables used: LogicalItemUsage, LogicalItem
  - Output: WRIN, Description, Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Total

## Key Decisions
- **Modelled after product-mix-details**: Same D/Q toggle pattern, same Total row via UNION ALL
- **No Refund column**: UI screenshot doesn't show Refund — excluded from output (data still in table if needed later)
- **Column names match UI**: WRIN, Description (not WrinNumber/ItemName)
- **No SortOrder in production query**: OutSystems handles sorting/filtering. Test queries keep SortOrder for convenience.
- **Total = sum of all ops (excl Refund)**: Sales + Promo + Discount + Crew + Manager + Waste
- **InputVar CTE**: Used for @SelectedView parameter binding (OutSystems quirk)
- **CLAUDE.md updated**: Added rule — no SortOrder/ORDER BY in production queries, only in tests

## Git Commits
- `d91d81b` — feat: Initial query scaffold + table docs
- `de70915` — fix: Match output to UI screenshot (removed Refund, renamed columns, added SortOrder)
- `8f3494a` — docs: Update session context with full history

## Test Queries Created
- `tests/test-ssms.sql` — Full query with DECLARE params + SortOrder for testing
- `tests/test-explore-data.sql` — DB-wide overview of LogicalItem/LogicalItemUsage data
- `tests/test-sites-with-data.sql` — List sites that have LogicalItemUsage data

## Next Steps
1. User picks a test site from test-sites-with-data.sql results
2. Run main query with real site data
3. Verify output matches UI expectations
4. Iterate based on feedback

## Notes for Next Session
- LogicalItemUsage HAS RefundNetAmt/RefundQty columns — excluded from output per UI but available if needed
- Module: Sales_UI (Stock section) for both tables
- No SortOrder in production queries — OutSystems handles sorting

## Quick Resume
To continue:
1. Read table docs: `database-context/tables/LogicalItem/README.md` and `LogicalItemUsage/README.md`
2. Check query: `queries/reports/product-mix-detail-by-logical-item/query.sql`
3. Continue from: User testing with real site data
