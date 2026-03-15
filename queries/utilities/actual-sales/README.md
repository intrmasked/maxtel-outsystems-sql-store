# ActualSales - Quarter-Hour Actual + Projected Product Sales

## Purpose

Returns **all 96 quarter-hour trading slots** (04:00 → next-day 04:00) per Pod with actual and projected product sales. Empty slots return `0.00` — DataHub expects every time slot regardless of sales activity.

## How It Works

1. **Quarter-Hour Scaffold** — Recursive CTE generates 96 slots from `@BusDate 04:15` to `@BusDate+1 04:00`
2. **Pod Scaffold** — Cross-joins with each Pod from `@PodList`
3. **ActualSales** — Aggregates `SalesFact` via `SWCPeriod` → `ProductMenu` → `BO_MenuItem` for the given BrandType
4. **HourlyTotals** — Derived from ActualSales (no extra DB scan) for ratio calculation
5. **SalesHour Join** — Gets `ProjectedSalesExclGST` per hour
6. **ProjectedProductSales** — `(ProjectedSalesExclGST / HourlyProductSales) * ProductSales` per quarter-hour

## Parameters

| Parameter | Type | Expand Inline | Description |
|-----------|------|---------------|-------------|
| `SiteId` | LongInteger | No | Site ID |
| `BusDate` | Date | No | Business date |
| `PodList` | Text | **Yes** | Comma-separated Pod codes (e.g., `'CO','DT'`) |
| `BrandType` | Text | No | Brand type filter (e.g., `MCD`) |

## Output

| Column | Type | Description |
|--------|------|-------------|
| `Pod` | Text | Point of Delivery code |
| `QtrHr` | DateTime | Quarter-hour timestamp (first = 04:15, last = 04:00 next day) |
| `ProductSales` | Decimal(18,2) | Actual product sales for this slot (0.00 if none) |
| `ProjectedProductSales` | Decimal(18,2) | Projected product sales based on hourly ratio (0.00 if no hourly data) |

## Output Row Count

`96 × number_of_pods` rows always returned (e.g., 2 Pods = 192 rows).

## Performance

- **Target**: < 1 second
- Single SalesFact scan (all actual data in one pass)
- HourlyTotals derived from ActualSales CTE (zero extra DB scans)
- Scaffold is pure CTE computation (no table access)
- `OPTION (MAXRECURSION 100)` for the 96-slot recursive CTE

## Files

| File | Purpose |
|------|---------|
| `query.sql` | Production query (OutSystems Advanced SQL) |
| `output-structure.json` | OutSystems Output Structure definition |
| `metadata.json` | Query metadata |
| `tests/test-ssms.sql` | SSMS sandbox test (uses DECLARE + STRING_SPLIT) |

## Tables Used

- `{SalesFact}` — Actual sales data (15-min granularity)
- `{SWCPeriod}` — Operating period (SiteId + BusDate filter)
- `{ProductMenu}` — Product menu link
- `{BO_MenuItem}` — Brand type classification
- `{SalesHour}` — Hourly projected sales

## Index Recommendations

**Status**: Recommended (Pending DBA review)

1. **IX_SalesHour_SiteId_StartDateTime** (SiteId, StartDateTime)
   - Impact: Medium
   - Reason: LEFT JOIN filtering on SiteId + DATEPART(HOUR, StartDateTime)
   - Status: Recommended
