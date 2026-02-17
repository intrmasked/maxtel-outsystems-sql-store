# Session: Product Mix Details - 2026-02-10

## Original Story/Requirements
Detail-level product mix report for a single site and date. Each row = one product from ProductSalesByOperation joined to ProductMenu for Code/Name.
- Code = ProductMenu.ProductId
- Name = ProductMenu.Name
- Sold = SalesNetAmt (changed from SalesGrossAmt in v1.1)
- Promo = PromoNetAmt
- Discount = DiscountNetAmt
- Emp Meals = CrewNetAmt
- Mgr Meals = ManagerNetAmt
- Waste = WasteNetAmt
- Total = TotalNetAmt
- SelectedView toggle: 'D' = Dollars, 'Q' = Quantity
- Total row identifiable by Name = 'Total' and Code = NULL
- No CashTotal, no Variance
- No multi-site (single SiteId, single Date)

## Status
- [X] Complete (query built v1.1)
- [ ] In Testing (user verifying Net amounts)

## Version History
| Version | Changes |
|---------|---------|
| v1.0 | Initial build with Gross Amounts |
| v1.1 | Switched to Net Amounts (SalesNetAmt etc.) per user request |
| v1.1 (perf review) | Reviewed for optimization - confirmed query is already well-optimized at ~125ms |

## Tables Documentation Created
- `database-context/tables/ProductMenu/` - [NEW] - Product menu items catalog

## Queries Created
- `queries/reports/product-mix-details/` - [needs-review]
  - Purpose: Detail product mix with Dollar/Quantity toggle
  - Tables: ProductSalesByOperation, ProductMenu
  - Output: Code, Name, Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Total

## Key Decisions
- **v1.1 Gross→Net Fix**: Original setup used GrossAmt columns. User added NetAmt columns and requested switch. Query now uses NetAmt.
- **SortOrder removed**: Initially added SortOrder as first column but caused OutSystems "Input string was not in a correct format" error due to column count mismatch. Removed — Total row identified by Name = 'Total'
- **No CashTotal/Variance**: Unlike product-mix-list, this detail view doesn't need CashTotal or Variance
- **InputVar CTE**: Used for @SelectedView parameter binding (OutSystems quirk)
- **Both D+Q columns in CTEs**: Select both GrossAmt and Quantity, CASE at final output for clean toggle
- **No ORDER BY in production**: User handles sorting in OutSystems (SSMS test has ORDER BY for convenience)
- **Total row via UNION ALL**: Simple sum of all products, SortOrder = 0
- **Test uses {TableName}**: Convention matches other tests in the repo (not [dbo].[TableName])
- **TotalRows removed from test**: User requested removal of verification column from test output
- **OPTION (RECOMPILE) kept in test**: This query uses `DECLARE @SiteId BIGINT` (not STRING_SPLIT), so RECOMPILE is safe and fine. The anti-pattern only applies when STRING_SPLIT is used — see product-mix-list for that case.
- **Performance confirmed**: ~125ms for single site/date. No further optimization needed. Single scan of ProductSalesByOperation + small ProductMenu join is already optimal.

## Next Steps
1. Verify query via MCP SQL Sandbox (bridge was unavailable)
2. User to test in OutSystems
3. Mark complete after verification

## Files Created/Modified
- `database-context/tables/ProductMenu/README.md` - [NEW]
- `queries/reports/product-mix-details/query.sql` - v1.1 (NetAmt)
- `queries/reports/product-mix-details/README.md`
- `queries/reports/product-mix-details/metadata.json`
- `queries/reports/product-mix-details/tests/test-ssms.sql` - v1.1 (NetAmt)
