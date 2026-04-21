# Session: ActualSales - 2026-03-15

## Original Story/Requirements
User provided an existing ActualSales CTE query that returns Pod, QtrHr, ProductSales, ProjectedProductSales. The query works but only returns rows where sales exist. Requirement: return **all 96 trading quarter-hour slots** (04:00→04:00) per Pod, with `ProductSales = 0.00` for empty slots. DataHub accepts `<ProductSales>0.00</ProductSales>`. Must be under 1 second.

## Status
- [X] Complete / [ ] In Testing / [ ] Needs Review
- Current step: v3 performance rewrite complete (pre-resolve pattern), ready for user testing
- Incomplete items: User verification in sandbox with real data

## v2 Performance Rewrite (2026-03-15)
**Problem**: v1 query was "incredibly slow" per user feedback.
**Result**: Still 10+ seconds — scaffold improvements helped but core SalesFact scan was the bottleneck.

## v3 Performance Rewrite (2026-03-15)
**Problem**: v2 still 10+ seconds. The real bottleneck was the SalesFact scan joining 3 tables (SWCPeriod + ProductMenu + BO_MenuItem) on every row.

**Root cause analysis**:
- SWCPeriod JOIN: only used for `WHERE SiteId + BusDate` → resolves to ONE PeriodId
- ProductMenu + BO_MenuItem JOIN: only used for `WHERE BrandType = @BrandType` → resolves to a small set of ProductMenuIds
- These 3 JOINs executed on EVERY SalesFact row during the scan = massive overhead

**v3 approach — Pre-resolve, then scan**:
1. **PeriodId CTE**: `SELECT Id FROM SWCPeriod WHERE SiteId + BusDate` → 1 row. Then `WHERE S.SWCPeriodId = (SELECT PeriodId FROM PeriodId)` — eliminates INNER JOIN.
2. **BrandMenuIds CTE**: `ProductMenu JOIN BO_MenuItem WHERE BrandType` → small set of IDs. Then `WHERE S.ProductMenuId IN (SELECT ProductMenuId FROM BrandMenuIds)` — eliminates 2 LEFT JOINs.
3. **SalesFact scan now has ZERO JOINs** — just WHERE filters on pre-resolved IDs.
4. All v2 improvements retained (static scaffold, window functions, pre-fetched Projections).

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
- **Pre-resolve pattern (v3)**: Resolve SWCPeriodId and BrandType→ProductMenuIds BEFORE scanning SalesFact. Eliminates all 3 JOINs from the fact table scan.
- **Quarter-hour scaffold**: Static number generator (cross-join) instead of recursive CTE → instant generation
- **Window function for HourlyTotals**: `SUM() OVER(PARTITION BY ...)` inline — no extra CTE/JOIN
- **SalesHour pre-fetch**: Projections CTE fetches max ~24 rows once, joins by integer hour
- **PodList**: Expand Inline = YES (comma-separated) — standard pattern for multi-value params
- **ActivePods**: Derived from ActualSales CTE (DISTINCT POD). No extra DB scan.
- **InputVar CTE**: Used for @SiteId, @BusDate, @BrandType (Lazy Parser fix). @PodList uses Expand Inline directly.

## Issues Encountered & Fixed
1. **PodList VALUES bug** (v1): `VALUES (@PodList)` with Expand Inline = YES caused column mismatch. Fixed by deriving ActivePods from ActualSales CTE.
2. **Performance** (v2): Recursive CTE + multiple scaffold JOINs = slow. Fixed with static number generator + window functions + pre-fetched Projections CTE.

## Next Steps
1. User tests v2 in sandbox
2. Verify 96 rows per pod appear (including zero-sales slots)
3. Verify ProjectedProductSales calculation matches expectations
4. Confirm performance improvement

## Notes for Next Session
- SalesHour table is in Sales_CS module
- BrandType is a filter, not an output column
- SalesHour has one row per hour — projected sales spread across 4 quarter-hours via ratio
- Projections CTE fetches both @BusDate and @BusDate+1 dates (trading day spans midnight)

## Quick Resume
To continue:
1. Read table docs: `database-context/tables/SalesHour/README.md`
2. Check query: `queries/utilities/actual-sales/query.sql`
3. Continue from: User testing v2 performance rewrite
