# Session: Raw Waste Detail — 2026-04-22

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_boards/board/t/Scheduling%20Team/Stories?workitem=3744
**PRD:** See prd.md and design.md in this folder

---

## Original Story/Requirements

Build the day detail screen. Shows a cross-tab table with wasteable logical items as rows and the four shifts as column groups, each cell showing quantity (in the item's UOM) and estimated cost value. Includes a shift summary strip at the top.

---

## Status
- [ ] Complete / [X] In Progress / [ ] Needs Review
- Current step: **PAUSED** — SQL queries written, summary strip built, detail screen paused pending category separator decision

---

## What's Done

### SQL Queries (committed)
- `queries/stock/waste/raw-waste-detail/query.sql` — item cross-tab (WRIN, Menu, Description, UOM, QTY+VALUE per shift)
- `queries/stock/waste/raw-waste-detail/query-summary.sql` — single row with per-shift totals for summary strip
- Both take `@StockPeriodId` + `@ConceptId`

### UI — Summary Strip (built)
- Widget tree with `summary-strip` container layout
- CSS: bordered card with rounded corners
- Expressions bound to `GetRawWasteDetail.RawWasteSummary.*`

### UI — Item Table (partially built)
- DataGrid with 22+ ListViewColumns for all shift QTY/VALUE pairs
- **BLOCKED**: Category separators (CHILL, FROZEN, MCCAFE groupings in mock) — no matching column in database
  - `LogicalItem.ItemType` only has Food/Paper/Other (too broad)
  - CHILL/FROZEN storage categories don't exist in data model
  - Need to decide: group by ItemType, add new column, or skip separators

---

## Screen Layout (from mock)

### Summary Strip (top)
- Day Total: $X.XX
- Overnight / Breakfast / Day / Night shift totals
- Total: $X.XX

### Item Table (cross-tab)
| WRIN | Menu | Description | Overnight QTY | Overnight VALUE | Breakfast QTY | Breakfast VALUE | Day QTY | Day VALUE | Night QTY | Night VALUE | Total QTY | Total VALUE |
|------|------|-------------|---------------|-----------------|---------------|-----------------|---------|-----------|-----------|-------------|-----------|-------------|

Plus Total row at bottom. Items grouped by category with separator rows.

---

## Design Decisions

### Advanced SQL required
- Cross-tab pivot (items as rows, shifts as column groups)
- Conditional SUM per shift (QTY and VALUE)
- Summary strip via separate query

### Summary strip as separate query
- `query-summary.sql` returns single row — cleaner than window functions in item query
- Both queries called in same data action

### GetOrCreate flow
- Detail screen calls `GetOrCreateRawWasteCount(SiteId, Date)` first
- Returns StockPeriodId used as input for both detail queries
- Ensures RawWasteCount rows exist before querying

---

## Tables Used
- `RawWasteCount` — EXISTING — waste quantities per item per shift
- `LogicalItem` — EXISTING — WRIN, ItemName, ItemType (menu)
- `PhysicalItem` — EXISTING — UnitName (UOM display)
- `DayParts` — EXISTING — shift structure

---

## Pending / Blockers
1. **Category separators** — need a data source for CHILL/FROZEN/MCCAFE groupings
2. **Total row** — to be calculated in UI (sum of all item rows)
3. **Slideout integration** — "+ Add/Edit" button opens entry panel (separate story)

---

## Quick Resume
To continue:
1. Read this context
2. Check queries: `queries/stock/waste/raw-waste-detail/`
3. Decide on category separator approach
4. Wire up DataGrid columns with expressions
