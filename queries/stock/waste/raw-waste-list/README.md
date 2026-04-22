# Raw Waste List

**Story:** [3746](https://dev.azure.com/MaxtelNZ/Scheduling/_boards/board/t/Scheduling%20Team/Stories?workitem=3746)
**Category:** Stock / Waste
**Created:** 2026-04-22

---

## Purpose

Returns one row per day per site for the Raw Waste browse screen. Each row shows waste cost broken down by shift (Overnight, Breakfast, Day, Night), a daily total, and a shift completion indicator (e.g. "2/4 shifts"). Shows ALL dates in the range including days with no data.

---

## Input Parameters

| Parameter | Type | Expand Inline | Description |
|-----------|------|---------------|-------------|
| `@SiteIds` | Text | **YES** | Comma-separated Site IDs |
| `@ConceptId` | Long Integer | No | Concept for DayParts lookup |
| `@StartDate` | Date | No | Date range start |
| `@EndDate` | Date | No | Date range end |

---

## Output Structure

| Column | Type | Description |
|--------|------|-------------|
| `Date` | Date | Calendar date |
| `SiteId` | Long Integer | Site identifier |
| `SiteName` | Text | Site display name |
| `StockPeriodId` | Long Integer | For navigation to detail screen. NULL = no data for this date |
| `OvernightTotal` | Decimal | SUM(WasteQty x CostPerUnit) for Order = 1 |
| `BreakfastTotal` | Decimal | SUM(WasteQty x CostPerUnit) for Order = 2 |
| `DayTotal` | Decimal | SUM(WasteQty x CostPerUnit) for Order = 3 |
| `NightTotal` | Decimal | SUM(WasteQty x CostPerUnit) for Order = 4 |
| `DailyTotal` | Decimal | Sum of all shifts |
| `ShiftsCompleted` | Integer | Count of shifts with at least 1 non-zero WasteQty |
| `TotalShifts` | Integer | Total shifts for this concept (always 4 for standard) |

---

## How It Works

1. **DateList CTE** generates every date in the range (recursive)
2. **SiteList CTE** resolves site names from comma-separated IDs
3. **Scaffold** = DateList x SiteList (CROSS JOIN — every date x every site)
4. **WasteData** aggregates RawWasteCount per site+date with conditional SUM per shift
5. **LEFT JOIN** Scaffold to WasteData — dates/sites with no data return NULLs (ISNULL → 0)
6. Ordered by Date DESC

---

## UI Display Logic

| Condition | Status | Shift columns |
|-----------|--------|---------------|
| `StockPeriodId = NullIdentifier()` | "No data" (grey pill) | "—" |
| `ShiftsCompleted = 0` | "No data" (grey pill) | "$0.00" |
| `ShiftsCompleted > 0 AND < TotalShifts` | "2/4" (amber pill) | Dollar values |
| `ShiftsCompleted = TotalShifts` | "4/4" (green pill) | Dollar values |

---

## Tables Used

- `Site` — resolve site names from IDs
- `StockPeriod` — filter by SiteId + date range
- `RawWasteCount` — waste quantities and cost per unit
- `DayParts` — shift structure (joined by ConceptId)

---

## Notes

- Uses Expand Inline = YES for @SiteIds (comma-separated list pattern)
- Shows all dates in range even without RawWasteCount data (LEFT JOIN from scaffold)
- Cost values use CostPerUnit snapshot from row creation time
- Shift order determined by DayParts.Order (1=Overnight, 2=Breakfast, 3=Day, 4=Night)
