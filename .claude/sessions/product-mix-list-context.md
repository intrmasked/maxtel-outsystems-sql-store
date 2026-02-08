# Session: Product Mix List - 2026-02-08

## Original Story/Requirements
Data is to be largely populated from the ProductSalesByOperation table (rollup of SalesFact).
Each row is a single product so you will need to sum for the SiteId and CalendarDate.
- Sold = SalesGrossAmt
- Promo = PromoGrossAmt
- Discount = DiscountGrossAmt
- Emp Meals = CrewGrossAmt
- Mgr Meals = ManagerGrossAmt
- Waste = WasteGrossAmt
- Total = TotalGrossAmt
- CashTotal = SalesFact.NetAmount (SalesFactTypeId=2, ProductSaleTypeId=1, DatePeriodDimensionId=15)
- Variance = TotalGrossAmt - CashTotal
- Include Site Total row + Grand Total row

## Status
- [X] Complete (query built)
- [ ] In Testing (user needs to verify CashTotal matches Cash->ProductSales)

## Tables Documentation Created
- `database-context/tables/ProductSalesByOperation/` - [NEW] - Rollup table for product mix

## Queries Created
- `queries/reports/product-mix-list/` - [needs-review]
  - Purpose: Product mix with variance from CashTotal
  - Tables: ProductSalesByOperation, SalesFact, Site
  - Output: SiteName, Date, Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Total, CashTotal, Variance

## Key Decisions
- **CashTotal Logic**: SalesFactTypeId=2, ProductSaleTypeId=1, DatePeriodDimensionId=15, null out other dimensions
- **Total Rows**: Used GROUPING SETS for Site Total + Grand Total
- **Variance**: Simple subtraction (TotalGrossAmt - CashTotal)

## Next Steps
1. User to test query in OutSystems or SSMS
2. Verify CashTotal matches Cash->ProductSales screen
3. Mark complete after verification

## Files Created
- `database-context/tables/ProductSalesByOperation/README.md`
- `queries/reports/product-mix-list/query.sql`
- `queries/reports/product-mix-list/README.md`
- `queries/reports/product-mix-list/metadata.json`
- `queries/reports/product-mix-list/tests/test-ssms.sql`
