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
- Include Grand Total row only (Site Total removed per user request)

## Status
- [X] Complete (query built v1.1)
- [ ] In Testing (user needs to verify CashTotal matches Cash->ProductSales)

## Version History
| Version | Commit | Changes |
|---------|--------|---------|
| v1.0 | 3d98a7f | Initial with Site Total + Grand Total |
| v1.1 | pending | Removed Site Total, Grand Total only |

## Tables Documentation Created
- `database-context/tables/ProductSalesByOperation/` - [NEW] - Rollup table for product mix

## Queries Created
- `queries/reports/product-mix-list/` - [needs-review]
  - Purpose: Product mix with variance from CashTotal
  - Tables: ProductSalesByOperation, SalesFact, Site
  - Output: SiteName, Date, Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Total, CashTotal, Variance

## Key Decisions
- **CashTotal Logic**: SalesFactTypeId=2, ProductSaleTypeId=1, DatePeriodDimensionId=15, null out other dimensions
- **Total Rows**: v1.0 had Site Total + Grand Total, v1.1 has Grand Total only
- **Site Total Archived**: `tests/test-with-site-totals.sql` has the code to restore Site Totals
- **Variance**: Simple subtraction (TotalGrossAmt - CashTotal)

## Next Steps
1. User to test query in OutSystems or SSMS
2. Verify CashTotal matches Cash->ProductSales screen
3. Mark complete after verification

## Files Created/Modified
- `database-context/tables/ProductSalesByOperation/README.md`
- `queries/reports/product-mix-list/query.sql` - v1.1 (no Site Total)
- `queries/reports/product-mix-list/README.md`
- `queries/reports/product-mix-list/metadata.json`
- `queries/reports/product-mix-list/tests/test-ssms.sql`
- `queries/reports/product-mix-list/tests/test-with-site-totals.sql` - Site Total code archived
