# Session: Raw Waste Detail — 2026-04-22

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_boards/board/t/Scheduling%20Team/Stories?workitem=3744
**PRD:** See prd.md and design.md in this folder

---

## Original Story/Requirements

Build the day detail screen. Shows a cross-tab table with wasteable logical items as rows and the four shifts as column groups, each cell showing quantity (in the item's UOM) and estimated cost value. Includes a shift summary strip at the top.

---

## Status
- [ ] Complete / [X] In Progress / [ ] Needs Review
- Current step: Writing detail query

---

## Screen Layout (from mock)

### Summary Strip (top)
- Day Total: $X.XX
- Overnight: $X.XX
- Breakfast: $X.XX
- Day: $X.XX
- Night: $X.XX
- Total: $X.XX

### Item Table (cross-tab)
| WRIN | Menu | Description | Overnight QTY | Overnight VALUE | Breakfast QTY | Breakfast VALUE | Day QTY | Day VALUE | Night QTY | Night VALUE | Total QTY | Total VALUE |
|------|------|-------------|---------------|-----------------|---------------|-----------------|---------|-----------|-----------|-------------|-----------|-------------|

Plus Total row at bottom.

---

## Design Decisions

### Advanced SQL required
- Cross-tab pivot (items as rows, shifts as column groups)
- Conditional SUM per shift (QTY and VALUE)
- Total row via UNION ALL
- Summary strip can be derived from the same query using window functions or calculated in UI from Total row

---

## Tables Used
- `RawWasteCount` — EXISTING — waste quantities per item per shift
- `LogicalItem` — EXISTING — WRIN, ItemName, ItemType (menu)
- `PhysicalItem` — EXISTING — UnitName (UOM display)
- `DayParts` — EXISTING — shift structure
- `LogicalItemSiteConfig` — EXISTING — filter wasteable items

---

## Query Input
- `@StockPeriodId` (Long Integer) — from list screen row click
- `@ConceptId` (Long Integer) — for DayParts lookup
