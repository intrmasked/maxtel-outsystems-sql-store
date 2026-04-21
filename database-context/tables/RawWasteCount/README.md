# Table: RawWasteCount

**OutSystems Entity**: RawWasteCount
**Module**: Stock (StockV2 schema)
**Purpose**: One row per LogicalItem x StockPeriod x DayPart — stores waste quantities and unit cost per shift
**Last Updated**: 2026-04-21

---

## Overview

`RawWasteCount` is the granular waste tracking table. Each row records how many units of a logical item were wasted during a specific shift (DayPart) on a specific day (StockPeriod). Rows are pre-created (initialised with WasteQty = 0) when a user first opens a date in the Raw Waste UI.

`CostPerUnit` is set once at row creation time (from BO_RawItemPrice / PhysicalItem.UnitsInCarton) and is never updated thereafter.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | Long Integer | PK, NOT NULL | Primary key, auto-increment |
| `StockPeriodId` | Long Integer | FK, NOT NULL | FK → StockPeriod. Identifies site + date |
| `LogicalItemId` | Long Integer | FK, NOT NULL | FK → LogicalItem. The item being tracked |
| `DayPartsId` | Long Integer | FK, NOT NULL | FK → DayParts. The shift (Overnight, Breakfast, Day, Night) |
| `WasteQty` | Integer | NOT NULL, DEFAULT 0 | Waste quantity in units. Whole numbers for EA items; decimal for KG/LTR |
| `CostPerUnit` | Decimal | NOT NULL | Unit cost at time of creation. = BO_RawItemPrice.Value / PhysicalItem.UnitsInCarton |
| `LastUpdatedAt` | Text | NULL | Timestamp of last update |

---

## Key Constraints

### Primary Key
- `Id` — Unique identifier

### Foreign Keys
- `StockPeriodId` → `StockPeriod`.`Id`
- `LogicalItemId` → `LogicalItem`.`Id`
- `DayPartsId` → `DayParts`.`Id`

### Logical Key
- (`StockPeriodId`, `LogicalItemId`, `DayPartsId`) — One row per item per shift per day

---

## Relationships

### Tables This Table References
- **StockPeriod** — The day/site this waste belongs to
  - Join: `RawWasteCount.StockPeriodId = StockPeriod.Id`
- **LogicalItem** — The item being wasted
  - Join: `RawWasteCount.LogicalItemId = LogicalItem.Id`
- **DayParts** — The shift
  - Join: `RawWasteCount.DayPartsId = DayParts.Id`

---

## Row Initialisation Logic

When a user first opens a date:
1. Resolve StockPeriodId via GetOrCreateStockPeriod(SiteId, Date)
2. Check if rows exist for that StockPeriodId
3. If no rows: create one row per (wasteable LogicalItem x DayPart)
4. CostPerUnit = BO_RawItemPrice.Value / PhysicalItem.UnitsInCarton
   - Price resolved via: PhysicalItem (from LogicalItem.DefaultPhysicalItemId) → BO_RawItemPrice (matching ConceptId + WrinNumber, most recent Effective date)

---

## Common Query Patterns

### Get All Waste for a StockPeriod
```sql
SELECT rwc.LogicalItemId, rwc.DayPartsId, rwc.WasteQty, rwc.CostPerUnit
FROM {RawWasteCount} rwc
WHERE rwc.StockPeriodId = @StockPeriodId
```

### Sum Waste by LogicalItem (across all shifts)
```sql
SELECT rwc.LogicalItemId, SUM(rwc.WasteQty) AS TotalWasteQty
FROM {RawWasteCount} rwc
WHERE rwc.StockPeriodId = @StockPeriodId
GROUP BY rwc.LogicalItemId
```

---

## Notes for OutSystems

- Use `{RawWasteCount}` in Advanced SQL
- CostPerUnit is snapshot at creation — does NOT update if BO_RawItemPrice changes
- WasteQty = 0 rows are pre-created but NOT persisted on save (zero-quantity rows are removed)
- After any WasteQty update, UpdateStockPeriodBalance must be called to sync RawWasteQty on StockPeriodBalance

---

## Related Tables

- [StockPeriod](../StockPeriod/README.md) — Parent: site + date
- [LogicalItem](../LogicalItem/README.md) — The logical item
- [DayParts](../DayParts/README.md) — The shift
- [PhysicalItem](../PhysicalItem/README.md) — For CostPerUnit resolution
- [BO_RawItemPrice](../BO_RawItemPrice/README.md) — Price source

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-04-21 | Initial documentation from Raw Waste PRD | Claude |
