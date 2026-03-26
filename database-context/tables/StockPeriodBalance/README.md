# Table: StockPeriodBalance

**OutSystems Entity**: StockPeriodBalance
**Module**: Stock (StockV2 schema)
**Database Table**: [dbo].[StockPeriodBalance]
**Purpose**: One row per StockPeriod + LogicalItem — stores all stock quantities in portions
**Last Updated**: 2026-03-25

---

## Overview

`StockPeriodBalance` is the core fact table for Raw Stock. Each row represents one logical item's stock position for a single day at a single site. All quantity fields are stored in **portions** — convert to display units via `PhysicalItem.PortionsPerUnit`.

Populated by the SyncListener (automated) or Settings card (manual). Fields like `DeliveredQty`, `TransferQty`, `RawWasteQty` are populated by separate external feed processes. `ActualClosedQty` is populated by the count entry flow.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | Integer | PK, NOT NULL | Primary key, auto-increment |
| `LogicalItemId` | Integer | FK, NOT NULL | FK → LogicalItem. The item this balance is for |
| `StockPeriodId` | Integer | FK, NOT NULL | FK → StockPeriod. The period (site+date) this balance belongs to |
| `OpenQty` | Decimal | NOT NULL | Starting count in portions. From prior period's ActualClosedQty (or TheoClosedQty if no actual count). Zero if no prior record |
| `StartIsTheo` | Boolean | NOT NULL | True when OpenQty was derived from TheoClosedQty (prior period had no actual count). Triggers red italic * in UI |
| `DeliveredQty` | Decimal | DEFAULT 0 | Deliveries in portions. Populated by external delivery feed |
| `TransferQty` | Decimal | DEFAULT 0 | Transfers in portions. Populated by external transfer feed |
| `RawWasteQty` | Decimal | DEFAULT 0 | Raw waste in portions. Populated by external waste feed |
| `TheoConsumedQty` | Decimal | NOT NULL | Theoretical consumption in portions. From LogicalItemUsage: SalesQty + CrewQty + DiscountQty + ManagerQty + WasteQty - RefundQty |
| `TheoClosedQty` | Decimal | NOT NULL | Theoretical end count in portions. Calculated: OpenQty + DeliveredQty + TransferQty - RawWasteQty - TheoConsumedQty |
| `ActualClosedQty` | Decimal | NULL | Actual counted end quantity in portions. Null until populated by count entry flow |
| `CloseQtyIsTheo` | Boolean | DEFAULT true | True when ActualClosedQty has not been entered. End Count displays TheoClosedQty with red italic * in UI |
| `ItemCostAtClose` | Decimal | NULL | Unit cost from BO_RawItemPrice at time of processing. Used for Var $ calculation |
| `IsWasteTracked` | Boolean | NOT NULL | Whether waste is tracked for this item |

---

## Key Constraints

### Primary Key
- `Id` — Unique identifier

### Foreign Keys
- `LogicalItemId` → `LogicalItem`.`Id`
- `StockPeriodId` → `StockPeriod`.`Id`

### Unique Constraints
- (`StockPeriodId`, `LogicalItemId`) — One balance per item per period

---

## Relationships

### Tables This Table References
- **StockPeriod** — Parent: the period (site+date)
  - Join: `StockPeriodBalance.StockPeriodId = StockPeriod.Id`
- **LogicalItem** — The logical item
  - Join: `StockPeriodBalance.LogicalItemId = LogicalItem.Id`

---

## Quantity Storage Model

All quantity fields are stored in **portions**. To convert for display:

```
displayValue = storedPortions / PhysicalItem.PortionsPerUnit
```

Join path to get PortionsPerUnit:
```
StockPeriodBalance → LogicalItem (on LogicalItemId)
                   → PhysicalItem (on LogicalItem.DefaultPhysicalItemId = PhysicalItem.Id)
```

---

## Derived/Display Fields

| Display Field | Calculation | Blank When |
|---------------|-------------|------------|
| Var Qty | (ActualClosedQty - TheoClosedQty) / PortionsPerUnit | CloseQtyIsTheo = true |
| Var $ | Var Qty * ItemCostAtClose | CloseQtyIsTheo = true |
| Var % | Var Qty / (TheoConsumedQty / PortionsPerUnit) * 100 | CloseQtyIsTheo = true OR TheoConsumedQty = 0 |

---

## Population Rules

### On Create (SyncListener)
- `OpenQty` = Prior day's ActualClosedQty (or TheoClosedQty if CloseQtyIsTheo=true). Zero if no prior record.
- `StartIsTheo` = True if from TheoClosedQty or no prior record
- `TheoConsumedQty` = From LogicalItemUsage
- `TheoClosedQty` = OpenQty + DeliveredQty + TransferQty - RawWasteQty - TheoConsumedQty
- `CloseQtyIsTheo` = true (default until actual count entered)
- `ActualClosedQty` = null
- `DeliveredQty`, `TransferQty`, `RawWasteQty` = 0

### On Update (re-run is idempotent)
- Recalculates: OpenQty, StartIsTheo, TheoConsumedQty, TheoClosedQty, ItemCostAtClose
- Never touches: DeliveredQty, TransferQty, RawWasteQty, ActualClosedQty, CloseQtyIsTheo

---

## Common Query Patterns

### Get Balances for Site + Date Range
```sql
SELECT SB.*
FROM {StockPeriodBalance} SB
JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
WHERE SP.SiteId = @SiteId
  AND SP.Date BETWEEN @StartDate AND @EndDate
```

### Aggregate Across Periods (Summary Screen)
```sql
SELECT
    SB.LogicalItemId,
    SUM(SB.RawWasteQty) AS TotalRawWaste,
    SUM(SB.DeliveredQty) AS TotalDeliveries,
    SUM(SB.TransferQty) AS TotalTransfers,
    SUM(SB.TheoConsumedQty) AS TotalTheoConsumed
FROM {StockPeriodBalance} SB
JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
WHERE SP.SiteId IN (@SiteIds)
  AND SP.Date BETWEEN @StartDate AND @EndDate
GROUP BY SB.LogicalItemId
```

---

## Notes for OutSystems

- Use `{StockPeriodBalance}` in Advanced SQL
- All quantities in portions — always divide by `PortionsPerUnit` for display
- `CloseQtyIsTheo` and `StartIsTheo` drive UI indicators (red italic *)
- Read-only from Raw Stock screens

---

## Related Tables

- [StockPeriod](../StockPeriod/README.md) — Parent: site + date
- [LogicalItem](../LogicalItem/README.md) — The logical item
- [PhysicalItem](../PhysicalItem/README.md) — For PortionsPerUnit conversion

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-25 | Initial documentation from spec + OutSystems entity screenshot | Claude |
