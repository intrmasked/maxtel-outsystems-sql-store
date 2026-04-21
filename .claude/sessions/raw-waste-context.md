# Session: Raw Waste — 2026-04-21

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_boards/board/t/Scheduling%20Team/Stories?workitem=3758

## Original Story/Requirements

### Feature Overview
Raw Waste allows staff to record food items discarded during each shift of a working day, tracked by logical item and unit count. Provides visibility into waste costs across shifts.

### PRD Stories
- **1.7.1**: View Raw Waste List (day rows with shift totals + completion status)
- **1.7.2**: View Raw Waste Detail (cross-tab: items as rows, shifts as columns, grouped by category)
- **1.7.3**: Enter Raw Waste (entry panel, select date+shift, enter quantities)
- **1.7.4**: Read-Only Mode for Stock Count Users
- **1.7.5**: Print Waste Form (PDF generation)

### Story: GetOrCreate RawWasteCount Rows
When a user first opens a date in Raw Waste, initialise RawWasteCount rows for that site+date.

## Status
- [X] Complete (confirmed by user)
- All requirements covered, Server Action + Service Action built in OutSystems

## Tables Documentation
- `database-context/tables/RawWasteCount/` - **NEW** - Waste per item per shift per day
- `database-context/tables/DayParts/` - **NEW** - Shift definitions (Overnight, Breakfast, Day, Night)
- `database-context/tables/LogicalItemSiteConfig/` - **NEW** - Per-site item active/wasteable flags
- `database-context/tables/LogicalItem/` - EXISTING - Master item list
- `database-context/tables/PhysicalItem/` - EXISTING - Physical item with UnitName, UnitsInCarton
- `database-context/tables/StockPeriod/` - EXISTING - Site + Date periods
- `database-context/tables/StockPeriodBalance/` - EXISTING - Stock balance per item per period
- `database-context/tables/BO_RawItemPrice/` - EXISTING - Historical item prices

## Queries Created
- `queries/stock/get-wasteable-items-with-cost/` - **COMPLETE**
  - Purpose: Returns LogicalItem × DayPart matrix with CostPerUnit for bulk-creating RawWasteCount rows
  - Tables: LogicalItem, LogicalItemSiteConfig, PhysicalItem, DayParts, BO_RawItemPrice
  - Used by: GetOrCreateRawWasteCount Server Action (Step 6 — only runs when no rows exist)

## OutSystems Build — Completed
- **Server Action**: `GetOrCreateRawWasteCount` (Stock_CS, Private) — under RawWaste folder
  - Inputs: SiteId, Date
  - Outputs: StockPeriodId, RawWasteCountList
  - Flow: Validate → GetOrCreateStockPeriod → Aggregate check → if empty: SQL + For Each Create → return list
- **Service Action**: `GetOrCreateRawWasteCount` (Stock_CS, Public) — wrapper

## Key Decisions
- **Aggregates-first rule** — added to CLAUDE.md. Only use Advanced SQL when Aggregates can't do the job
- **This query needs Advanced SQL** — INNER JOIN for item × shift matrix + OUTER APPLY TOP 1 for latest price can't be done with Aggregates
- **Check existing rows uses Aggregate** — simple COUNT on RawWasteCount by StockPeriodId
- **CostPerUnit = BO_RawItemPrice.Value / PhysicalItem.UnitsInCarton** — snapshot at creation, never updated
- **CROSS JOIN bug fixed** — original query used `CROSS JOIN ... WHERE` which is invalid SQL; changed to `INNER JOIN ... ON`
- **COUNT(DISTINCT) OVER() bug fixed** — not allowed in SQL Server window functions; removed from test query

## Test Results
- `test-check-tables.sql` — confirmed all tables have data except LogicalItemSiteConfig (only site 3191, no IsWasteable=1 rows yet — expected for new feature)
- Query is structurally correct, will return data once LogicalItemSiteConfig is configured for a site

## Next Steps
1. Move to story **1.7.1**: Raw Waste List query
2. Then **1.7.2**: Raw Waste Detail query

## Quick Resume
To continue:
1. Read this session context
2. Query: `queries/stock/get-wasteable-items-with-cost/query.sql`
3. Next story: 1.7.1 Raw Waste List
