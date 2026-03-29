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
- Current step: Total Variance card wiring documented in `outsystems-expressions.md`. Query + output structure already exist. User needs to add second Advanced SQL node in OutSystems and wire expressions.
- Incomplete items: Sandbox verification with real data, user confirmation

## Tables Documentation Created
- `database-context/tables/StockPeriodBalance/` — **NEW** — Core fact table, all quantities in portions
- `database-context/tables/StockPeriod/` — **NEW** — One record per Site + Date
- `database-context/tables/PhysicalItem/` — **EXISTING** (docs created) — UnitName, PortionsPerUnit conversion
- `database-context/tables/CentralStockItem/` — **EXISTING** (docs created) — DefaultCountPeriodId for frequency filter
- `database-context/tables/LogicalItem/` — **UPDATED** — Added ItemType column, relationships to new tables

## Queries Created
- `queries/stock/raw-stock-list/query.sql` — **GetRawStockList** — In Progress
  - Purpose: Main list, one row per LogicalItem
  - Tables: StockPeriodBalance, StockPeriod, LogicalItem, PhysicalItem, CentralStockItem, Site
  - Output: LogicalItemId, ItemName, ItemType, UnitName, PortionsPerUnit, DefaultCountPeriodId, StartingCount, StartIsTheo, RawWaste, Deliveries, Transfers, UnitsCPM, EndCount, CloseQtyIsTheo, VarQty, VarDollar, VarPercent, ItemCostAtClose, SiteId, SiteName

- `queries/stock/raw-stock-list/query-total-variance.sql` — **GetRawStockTotalVariance** — In Progress
  - Purpose: Total Variance card (TotalVarDollar + TotalVarPercent)
  - Only rows where CloseQtyIsTheo = false qualify
  - Card shows: `-$63.50  -8.2%` format (red for negative, green for positive)
  - **NEXT TASK**: Wire this query to the Total Variance card UI

## Key Decisions
- **InputVar CTE pattern**: Used for @StartDate, @EndDate, @ItemSearch to handle OutSystems Lazy Parser bug
- **Expand Inline = YES**: Used for @SiteIds, @ProductTypes, @CountFrequencies (comma-separated lists)
- **No pagination in SQL**: Pagination handled by OutSystems application layer
- **Var % formula**: Uses `(ActualClosedQty - TheoClosedQty) / TotalTheoConsumed * 100` — in portions (PPU cancels out)
- **Total Variance card**: Separate query, same CTEs/filters. Only CloseQtyIsTheo=false rows.
- **JOIN (not LEFT JOIN)**: Rows with null DefaultPhysicalItemId excluded per spec
- **ORDER BY removed from production query**: OutSystems handles sorting
- **RowType column removed**: Total row identified by `ItemName = 'Total'` and `LogicalItemId = 0`
- **CAST on SUM columns**: Safety net for nvarchar columns in OutSystems backend
- **SiteId/SiteName added**: Joined to `{Site}` table via SiteList CTE. For single site shows that site, for multi-site shows MIN(SiteId). Total row gets `0`/`''`.
- **OutSystems expressions doc**: Created `outsystems-expressions.md` with all column expressions + styles (bold total row, orange StartIsTheo, red CloseQtyIsTheo, green/red variance colors)

## Parameters
| Parameter | Expand Inline | Notes |
|-----------|--------------|-------|
| @SiteIds | YES | IntegerList — always populated (single site or all tenant sites) |
| @StartDate | No | Date |
| @EndDate | No | Date |
| @ItemSearch | No | Text, optional, LIKE filter |
| @ProductTypes | YES | TextList, optional (Food/Paper/Other) |
| @CountFrequencies | YES | IntegerList, optional |

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
- `queries/stock/raw-stock-list/outsystems-expressions.md`
- `queries/stock/raw-stock-list/tests/test-ssms.sql`
- `queries/stock/raw-stock-list/tests/test-total-variance.sql`
- `queries/stock/raw-stock-list/tests/test-find-data.sql`

## Next Steps
1. **Total Variance card** — wire `query-total-variance.sql` to the UI card (screenshot provided: `-$63.50 -8.2%`)
2. Sandbox verification with real StockPeriodBalance data
3. Mark complete when user confirms

## Change Log
| Date | Change |
|------|--------|
| 2026-03-25 | Initial queries written, table docs created |
| 2026-03-28 | Verified against spec v0.4, removed RowType, removed ORDER BY, added CAST safety, added test-find-data.sql |
| 2026-03-29 | Frontend built. Added SiteId/SiteName columns (Site join). Created outsystems-expressions.md. Detail screen query created separately. |
| 2026-03-29 | Total Variance card wiring documented — expressions, styles, layout, and OutSystems setup steps added to outsystems-expressions.md |

## Notes for Next Session
- All quantities stored in **portions** — always divide by PortionsPerUnit for display
- `CloseQtyIsTheo` / `StartIsTheo` are boolean flags driving UI indicators (red italic *)
- Multi-site support via Expand Inline = YES on @SiteIds — OutSystems always passes site IDs, never null
- Var % denominator is TotalTheoConsumed (summed across ALL periods), not just last period
- Tables are in `StockV2` schema in actual DB but use `{TableName}` in OutSystems
- OutSystems expressions/styles documented in `outsystems-expressions.md`
- Total Variance card screenshot shows: `TOTAL VARIANCE` header, `-$63.50` in red, `-8.2%` in red/green
- Detail screen query is separate: `queries/stock/raw-stock-detail/` — see `raw-stock-detail-context.md`

## Quick Resume
To continue:
1. Read session context: `.claude/sessions/raw-stock-list-context.md`
2. Read table docs: `database-context/tables/StockPeriodBalance/README.md` (+ others)
3. Check queries: `queries/stock/raw-stock-list/query.sql` and `query-total-variance.sql`
4. Check expressions: `queries/stock/raw-stock-list/outsystems-expressions.md`
5. **Continue from**: Total Variance card — wire `query-total-variance.sql` to the card UI. User provided screenshot of the card design.
