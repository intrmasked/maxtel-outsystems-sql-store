# Session: Product Mix Details - 2026-02-10

## Original Story/Requirements
Detail-level product mix report for a single site and date. Each row = one product from ProductSalesByOperation joined to ProductMenu for Code/Name.
- Code = ProductMenu.ProductId
- Name = ProductMenu.Name
- Sold = SalesGrossAmt (or SalesQuantity)
- Promo = PromoGrossAmt (or PromoQuantity)
- Discount = DiscountGrossAmt (or DiscountQuantity)
- Emp Meals = CrewGrossAmt (or CrewQuantity)
- Mgr Meals = ManagerGrossAmt (or ManagerQuantity)
- Waste = WasteGrossAmt (or WasteQuantity)
- Total = TotalGrossAmt (or TotalQuantitySold)
- SelectedView toggle: 'D' = Dollars, 'Q' = Quantity
- Total row identifiable by Name = 'Total' and Code = NULL
- No CashTotal, no Variance
- No multi-site (single SiteId, single Date)

## Status
- [/] In Progress (query built v1.0)
- [ ] In Testing (pending sandbox verification)

## Tables Documentation Created
- `database-context/tables/ProductMenu/` - [NEW] - Product menu items catalog

## Queries Created
- `queries/reports/product-mix-details/` - [needs-review]
  - Purpose: Detail product mix with Dollar/Quantity toggle
  - Tables: ProductSalesByOperation, ProductMenu
  - Output: Code, Name, Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Total

## Key Decisions
- **SortOrder removed**: Initially added SortOrder as first column but caused OutSystems "Input string was not in a correct format" error due to column count mismatch. Removed — Total row identified by Name = 'Total'
- **No CashTotal/Variance**: Unlike product-mix-list, this detail view doesn't need CashTotal or Variance
- **InputVar CTE**: Used for @SelectedView parameter binding (OutSystems quirk)
- **Both D+Q columns in CTEs**: Select both GrossAmt and Quantity, CASE at final output for clean toggle
- **No ORDER BY in production**: User handles sorting in OutSystems (SSMS test has ORDER BY for convenience)
- **Total row via UNION ALL**: Simple sum of all products, SortOrder = 0
- **Test uses {TableName}**: Convention matches other tests in the repo (not [dbo].[TableName])

## Next Steps
1. Verify query via MCP SQL Sandbox (bridge was unavailable)
2. User to test in OutSystems
3. Mark complete after verification

## Files Created/Modified
- `database-context/tables/ProductMenu/README.md` - [NEW]
- `queries/reports/product-mix-details/query.sql` - v1.0
- `queries/reports/product-mix-details/README.md`
- `queries/reports/product-mix-details/metadata.json`
- `queries/reports/product-mix-details/tests/test-ssms.sql` - uses {TableName} convention
