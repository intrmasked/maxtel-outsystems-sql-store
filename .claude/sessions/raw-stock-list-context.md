# Session: Raw Stock — Summary List | 2026-03-25

## Original Story/Requirements
Feature 3.1 — Raw Stock Summary List Screen. Route: `Stock > Raw Stock`.
One row per LogicalItem with aggregated stock movements across a date range.
Starting Count = first period, End Count = last period, movement columns summed.
Total Variance card (separate query) across all pages.
Depends on Feature 2.1 (LogicalItemUsage).

Full spec provided by user — see story in conversation history.

## Status
- [ ] Complete / [X] In Progress / [ ] Needs Review
- Current step: Queries verified against full spec. ORDER BY removed from production query. Awaiting sandbox testing.
- Incomplete items: Sandbox verification, user testing

## Tables Documentation Created
- `database-context/tables/StockPeriodBalance/` — **NEW** — Core fact table, all quantities in portions
- `database-context/tables/StockPeriod/` — **NEW** — One record per Site + Date
- `database-context/tables/PhysicalItem/` — **EXISTING** (docs created) — UnitName, PortionsPerUnit conversion
- `database-context/tables/CentralStockItem/` — **EXISTING** (docs created) — DefaultCountPeriodId for frequency filter
- `database-context/tables/LogicalItem/` — **UPDATED** — Added ItemType column, relationships to new tables

## Queries Created
- `queries/stock/raw-stock-list/query.sql` — **GetRawStockList** — In Progress
  - Purpose: Main paginated list, one row per LogicalItem
  - Tables: StockPeriodBalance, StockPeriod, LogicalItem, PhysicalItem, CentralStockItem
  - Output: LogicalItemId, ItemName, ItemType, UnitName, StartingCount, RawWaste, Deliveries, Transfers, UnitsCPM, EndCount, VarQty, VarDollar, VarPercent + flags + TotalRowCount

- `queries/stock/raw-stock-list/query-total-variance.sql` — **GetRawStockTotalVariance** — In Progress
  - Purpose: Total Variance card (TotalVarDollar + TotalVarPercent)
  - Only rows where CloseQtyIsTheo = false qualify

## Key Decisions
- **InputVar CTE pattern**: Used for @StartDate, @EndDate, @ItemSearch to handle OutSystems Lazy Parser bug
- **Expand Inline = YES**: Used for @SiteIds, @ProductTypes, @CountFrequencies (comma-separated lists)
- **No pagination in SQL**: Pagination handled by OutSystems application layer, not in query. Removed OFFSET/FETCH, PageSize, PageOffset, TotalRowCount.
- **Var % formula**: Uses `(ActualClosedQty - TheoClosedQty) / TotalTheoConsumed * 100` — note this is in portions (no PortionsPerUnit needed since it cancels out)
- **Total Variance card**: Separate query, same CTEs/filters, no pagination. Only CloseQtyIsTheo=false rows.
- **JOIN (not LEFT JOIN)**: LogicalItem → PhysicalItem is INNER JOIN — rows with null DefaultPhysicalItemId are excluded per spec edge case
- **ORDER BY removed from production query**: OutSystems handles sorting in application layer. Test queries keep ORDER BY for convenience.

## Parameters
| Parameter | Expand Inline | Notes |
|-----------|--------------|-------|
| @SiteIds | YES | IntegerList |
| @StartDate | No | Date |
| @EndDate | No | Date |
| @ItemSearch | No | Text, optional, LIKE filter |
| @ProductTypes | YES | TextList, optional (Food/Paper/Other) |
| @CountFrequencies | YES | IntegerList, optional |
| @PageSize | No | Integer (main query only) |
| @PageOffset | No | Integer, 0-based (main query only) |

## Files Created
- `database-context/tables/StockPeriodBalance/README.md`
- `database-context/tables/StockPeriod/README.md`
- `database-context/tables/PhysicalItem/README.md`
- `database-context/tables/CentralStockItem/README.md`
- `database-context/tables/LogicalItem/README.md` (updated)
- `queries/stock/raw-stock-list/query.sql`
- `queries/stock/raw-stock-list/query-total-variance.sql`
- `queries/stock/raw-stock-list/output-structure.json`
- `queries/stock/raw-stock-list/output-structure-total-variance.json`
- `queries/stock/raw-stock-list/metadata.json`
- `queries/stock/raw-stock-list/README.md`
- `queries/stock/raw-stock-list/tests/test-ssms.sql`
- `queries/stock/raw-stock-list/tests/test-total-variance.sql`

## Next Steps
1. Sandbox verification via MCP SQL Sandbox Bridge
2. User testing + feedback
3. Adjustments based on test results
4. Mark complete when user confirms

## Notes for Next Session
- All quantities stored in **portions** — always divide by PortionsPerUnit for display
- `CloseQtyIsTheo` / `StartIsTheo` are boolean flags driving UI indicators (red italic *)
- Multi-site support via Expand Inline = YES on @SiteIds
- Var % denominator is TotalTheoConsumed (summed across ALL periods), not just last period
- Tables are in `StockV2` schema in actual DB but use `{TableName}` in OutSystems

## Quick Resume
To continue:
1. Read session context: `.claude/sessions/raw-stock-list-context.md`
2. Read table docs: `database-context/tables/StockPeriodBalance/README.md` (+ others)
3. Check queries: `queries/stock/raw-stock-list/query.sql` and `query-total-variance.sql`
4. Continue from: Sandbox testing
