# Raw Waste List

**Story:** [3746](https://dev.azure.com/MaxtelNZ/Scheduling/_boards/board/t/Scheduling%20Team/Stories?workitem=3746)
**Category:** Stock
**Created:** 2026-04-22

---

## Purpose

Returns one row per day for the Raw Waste browse screen. Each row shows waste cost broken down by shift (Overnight, Breakfast, Day, Night), a daily total, and a shift completion indicator (e.g. "2/4 shifts").

---

## Input Parameters

| Parameter | Type | Expand Inline | Description |
|-----------|------|---------------|-------------|
| `@SiteId` | Long Integer | No | Site to filter by |
| `@ConceptId` | Long Integer | No | Concept for DayParts lookup |
| `@StartDate` | Date | No | Date range start |
| `@EndDate` | Date | No | Date range end |

---

## Output Structure

| Column | Type | Description |
|--------|------|-------------|
| `Date` | Date | StockPeriod date |
| `StockPeriodId` | Long Integer | For navigation to detail screen |
| `OvernightTotal` | Decimal | SUM(WasteQty × CostPerUnit) for Order = 1 |
| `BreakfastTotal` | Decimal | SUM(WasteQty × CostPerUnit) for Order = 2 |
| `DayTotal` | Decimal | SUM(WasteQty × CostPerUnit) for Order = 3 |
| `NightTotal` | Decimal | SUM(WasteQty × CostPerUnit) for Order = 4 |
| `DailyTotal` | Decimal | Sum of all shifts |
| `ShiftsCompleted` | Integer | Count of shifts with at least 1 non-zero WasteQty |
| `TotalShifts` | Integer | Total shifts for this concept (always 4 for standard) |

---

## How It Works

1. Joins `StockPeriod` → `RawWasteCount` → `DayParts` (filtered by ConceptId)
2. Uses conditional `SUM(CASE WHEN dp.Order = N ...)` to pivot shift values into columns
3. Uses `COUNT(DISTINCT CASE WHEN WasteQty > 0 THEN dp.Id END)` for shift completion
4. Groups by Date + StockPeriodId — one row per day
5. Ordered by Date DESC (most recent first)

---

## Tables Used

- `StockPeriod` — filter by SiteId + date range
- `RawWasteCount` — waste quantities and cost per unit
- `DayParts` — shift structure (joined by ConceptId)

---

## Notes

- Only returns days that have RawWasteCount rows (created by GetOrCreate flow)
- Days with no waste entries will show all zeros but still appear (WasteQty defaults to 0)
- Cost values use CostPerUnit snapshot from row creation time
- Shift order is determined by DayParts.Order (1=Overnight, 2=Breakfast, 3=Day, 4=Night)
