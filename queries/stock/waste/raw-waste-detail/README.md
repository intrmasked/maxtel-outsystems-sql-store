# Raw Waste Detail

**Story:** [3744](https://dev.azure.com/MaxtelNZ/Scheduling/_boards/board/t/Scheduling%20Team/Stories?workitem=3744)
**Category:** Stock / Waste
**Created:** 2026-04-22

---

## Purpose

Two queries for the Raw Waste detail screen:

1. **query.sql** — Item table: one row per wasteable logical item, QTY + VALUE pivoted per shift
2. **query-summary.sql** — Summary strip: single row with per-shift totals for the day

---

## Input Parameters (both queries)

| Parameter | Type | Expand Inline | Description |
|-----------|------|---------------|-------------|
| `@StockPeriodId` | Long Integer | No | StockPeriod for this day (from list screen click) |
| `@ConceptId` | Long Integer | No | Concept for DayParts lookup |

---

## Output Structure — Item Table (query.sql)

| Column | Type | Description |
|--------|------|-------------|
| `WRIN` | Text | LogicalItem.WrinNumber |
| `Menu` | Text | LogicalItem.ItemType (Food, Paper, Other) |
| `Description` | Text | LogicalItem.ItemName |
| `UOM` | Text | PhysicalItem.UnitName (Pattie, Each, KG, etc.) |
| `OvernightQty` | Decimal | WasteQty for shift Order=1 |
| `OvernightValue` | Decimal | WasteQty x CostPerUnit for Order=1 |
| `BreakfastQty` | Decimal | WasteQty for shift Order=2 |
| `BreakfastValue` | Decimal | WasteQty x CostPerUnit for Order=2 |
| `DayQty` | Decimal | WasteQty for shift Order=3 |
| `DayValue` | Decimal | WasteQty x CostPerUnit for Order=3 |
| `NightQty` | Decimal | WasteQty for shift Order=4 |
| `NightValue` | Decimal | WasteQty x CostPerUnit for Order=4 |
| `TotalQty` | Decimal | Sum of QTY across all shifts |
| `TotalValue` | Decimal | Sum of VALUE across all shifts |

## Output Structure — Summary Strip (query-summary.sql)

| Column | Type | Description |
|--------|------|-------------|
| `OvernightTotal` | Decimal | Total waste cost for Overnight shift |
| `BreakfastTotal` | Decimal | Total waste cost for Breakfast shift |
| `DayTotal` | Decimal | Total waste cost for Day shift |
| `NightTotal` | Decimal | Total waste cost for Night shift |
| `DailyTotal` | Decimal | Total waste cost for all shifts |
| `ShiftsCompleted` | Integer | Shifts with at least 1 non-zero WasteQty |
| `TotalShifts` | Integer | Total shifts for this concept |

---

## How It Works

### Item Table (query.sql)
1. Joins `RawWasteCount` -> `LogicalItem` -> `PhysicalItem` for item info
2. Joins `DayParts` filtered by ConceptId for shift structure
3. Conditional SUM pivots each shift into QTY + VALUE column pairs
4. Groups by item (WRIN, Menu, Description, UOM) — one row per item

### Summary Strip (query-summary.sql)
1. Joins `RawWasteCount` -> `DayParts` (no item info needed)
2. Conditional SUM per shift for totals
3. COUNT DISTINCT for shift completion
4. Returns single row

---

## Tables Used

- `RawWasteCount` — waste quantities and cost per unit
- `LogicalItem` — WRIN, item name, menu type (item table only)
- `PhysicalItem` — UOM / UnitName (item table only)
- `DayParts` — shift structure (joined by ConceptId)

---

## Notes

- Only items with RawWasteCount rows appear (created by GetOrCreate when date is first opened)
- If StockPeriodId has no RawWasteCount rows, queries return empty — UI shows "No data"
- Total row in item table is calculated in the UI (sum of all item rows)
- CostPerUnit is snapshot from row creation time
