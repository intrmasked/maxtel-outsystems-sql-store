# Session: GetOrCreate RawWasteCount — 2026-04-21

**PRD:** See `prd.md` in this folder
**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_boards/board/t/Scheduling%20Team/Stories?workitem=3758

## Story
When a user first opens a date in Raw Waste, initialise RawWasteCount rows for that site+date.

## Status
- [X] Complete

## Queries Created
- `queries/utilities/get-wasteable-items-with-cost/` - **COMPLETE**
  - Returns LogicalItem × DayPart matrix with CostPerUnit for bulk-creating RawWasteCount rows
  - Tables: LogicalItem, LogicalItemSiteConfig, PhysicalItem, DayParts, BO_RawItemPrice
  - Used by: GetOrCreateRawWasteCount Server Action (only runs when no rows exist)

## OutSystems Build — Completed
- **Server Action**: `GetOrCreateRawWasteCount` (Stock_CS, Private) — under RawWaste folder
  - Inputs: SiteId, Date
  - Outputs: StockPeriodId, RawWasteCountList
  - Flow: Validate → GetOrCreateStockPeriod → Aggregate check → if empty: SQL + For Each Create → return list
- **Service Action**: `GetOrCreateRawWasteCount` (Stock_CS, Public) — wrapper

## Key Decisions
- **Aggregates-first rule** — added to CLAUDE.md
- **Advanced SQL needed** — INNER JOIN for item × shift matrix + OUTER APPLY TOP 1 for latest price
- **Check existing rows uses Aggregate** — simple COUNT
- **CostPerUnit** = BO_RawItemPrice.Value / PhysicalItem.UnitsInCarton — snapshot at creation
- **CROSS JOIN → INNER JOIN fix** — `CROSS JOIN ... WHERE` is invalid SQL
- **COUNT(DISTINCT) OVER() fix** — not allowed in SQL Server window functions

## Test Results
- All tables have data except LogicalItemSiteConfig (only site 3191, no IsWasteable=1 yet — expected for new feature)
- Query is structurally correct
