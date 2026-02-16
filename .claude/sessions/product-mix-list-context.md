# Session: Product Mix List - 2026-02-08

## Original Story/Requirements
Data is to be largely populated from the ProductSalesByOperation table (rollup of SalesFact).
Each row is a single product so you will need to sum for the SiteId and CalendarDate.
- Sold = SalesNetAmt (changed from SalesGrossAmt in v2.0)
- Promo = PromoNetAmt
- Discount = DiscountNetAmt
- Emp Meals = CrewNetAmt
- Mgr Meals = ManagerNetAmt
- Waste = WasteNetAmt
- Total = TotalNetAmt
- CashTotal = SalesFact.NetAmount (SalesFactTypeId=2, ProductSaleTypeId=1, DatePeriodDimensionId=15)
- Variance = TotalNetAmt - CashTotal
- Include Grand Total row only (Site Total removed per user request)

## Status
- [X] Complete (query built v2.0)
- [ ] In Testing (user needs to verify CashTotal matches Cash->ProductSales)

## Version History
| Version | Commit | Changes |
|---------|--------|---------|
| v1.0 | 3d98a7f | Initial with Site Total + Grand Total (GrossAmt) |
| v1.1 | 55ad570 | Removed Site Total, Grand Total only |
| v1.2 | 2291672 | Added SiteId output, fixed SiteName priority |
| v2.0 | pending | Switched from GrossAmt to NetAmt columns |

## Tables Documentation Created
- `database-context/tables/ProductSalesByOperation/` - [UPDATED] - Added NetAmt columns

## Queries Created
- `queries/reports/product-mix-list/` - [needs-review]
  - Purpose: Product mix with variance from CashTotal
  - Tables: ProductSalesByOperation, SalesFact, Site
  - Output: SiteId, SiteName, Date, Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Total, CashTotal, Variance

## Key Decisions
- **v2.0 Gross→Net Fix**: Original setup used GrossAmt columns by mistake. User added NetAmt columns to table and populated them. Query now uses NetAmt.
- **CashTotal Logic**: SalesFactTypeId=2, ProductSaleTypeId=1, DatePeriodDimensionId=15, null out other dimensions
- **Total Rows**: Grand Total only (Site Total archived in tests/test-with-site-totals.sql)
- **Variance**: TotalNetAmt - CashTotal

## Files Created/Modified
- `database-context/tables/ProductSalesByOperation/README.md` - Updated with NetAmt columns
- `queries/reports/product-mix-list/query.sql` - v2.0 (NetAmt)
- `queries/reports/product-mix-list/tests/test-ssms.sql` - Updated to NetAmt
- `queries/reports/product-mix-list/tests/test-with-site-totals.sql` - Site Total code archived (still GrossAmt)
