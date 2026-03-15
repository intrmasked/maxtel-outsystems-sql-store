# Session: ActualSales - 2026-03-15

## Original Story/Requirements
User provided an existing ActualSales CTE query that returns Pod, QtrHr, ProductSales, ProjectedProductSales. The query works but only returns rows where sales exist. Requirement: return **all 96 trading quarter-hour slots** (04:00→04:00) per Pod, with `ProductSales = 0.00` for empty slots. DataHub accepts `<ProductSales>0.00</ProductSales>`. Must be under 1 second.

## Status
- [ ] Complete / [X] In Testing / [ ] Needs Review
- Current step: Query built, initial OutSystems error fixed (PodList VALUES bug), awaiting user re-test
- Incomplete items: User verification in sandbox with real data

## Tables Documentation Created
- `database-context/tables/SalesHour/` - **NEW** - Hourly sales projections/actuals per site

## Tables Documentation Used (Existing)
- `database-context/tables/SalesFact/` - EXISTING - Main sales fact table
- `database-context/tables/SWCPeriod/` - EXISTING - Operating period
- `database-context/tables/ProductMenu/` - EXISTING - Product menu catalog
- `database-context/tables/BO_MenuItem/` - EXISTING - Menu item classification (BrandType)

## Queries Created
- `queries/utilities/actual-sales/` - Status: in-testing
  - Purpose: Quarter-hour actual + projected product sales with full scaffold
  - Tables used: SalesFact, SWCPeriod, ProductMenu, BO_MenuItem, SalesHour
  - Output: Pod, QtrHr, ProductSales, ProjectedProductSales
  - Row count: 96 × number_of_pods (always)

## Key Decisions
- **Quarter-hour scaffold**: Recursive CTE from 04:15 to 04:00 next day (96 slots) → Trading day starts at 04:00
- **Performance**: Single SalesFact scan, HourlyTotals derived from ActualSales CTE (no extra DB hit)
- **PodList**: Expand Inline = YES (comma-separated) — standard pattern for multi-value params
- **PodList scaffold fix**: Cannot use `VALUES (@PodList)` with Expand Inline — SQL sees multiple columns. Instead derive ActivePods from ActualSales CTE (DISTINCT POD). No extra DB scan.
- **InputVar CTE**: Used for @SiteId, @BusDate, @BrandType (Lazy Parser fix). @PodList uses Expand Inline directly.
- **Zero-fill**: LEFT JOIN scaffold to actuals — ISNULL(ProductSales, 0) for empty slots
- **ProjectedProductSales ratio**: When HourlyProductSales = 0, returns 0 (avoids divide-by-zero)

## Issues Encountered & Fixed
1. **PodList VALUES bug** (2026-03-15): `VALUES (@PodList)` with Expand Inline = YES caused "PodSource has more columns than specified". When OutSystems expands `@PodList` to `'CO','DT'`, SQL Server sees 2 columns but alias declared 1. **Fix**: Removed VALUES approach, derive ActivePods from ActualSales CTE via `SELECT DISTINCT [POD]`.

## Next Steps (if incomplete)
1. User re-tests in sandbox after PodList fix
2. Verify 96 rows per pod appear (including zero-sales slots)
3. Verify ProjectedProductSales calculation matches expectations
4. Confirm performance < 1s

## Notes for Next Session
- SalesHour table is in Sales_CS module
- The original query used `B.[BrandType]` in SELECT and GROUP BY — removed from scaffold version since BrandType is a filter, not an output column
- SalesHour has one row per hour — projected sales spread across 4 quarter-hours via ratio

## Quick Resume
To continue:
1. Read table docs: `database-context/tables/SalesHour/README.md`
2. Check query: `queries/utilities/actual-sales/query.sql`
3. Continue from: User testing phase
