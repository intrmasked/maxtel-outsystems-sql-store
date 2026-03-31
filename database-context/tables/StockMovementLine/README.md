# Table: StockMovementLine

**OutSystems Entity**: StockMovementLine
**Module**: Stock (Stock_CS)
**Purpose**: Individual line items within a stock movement (delivery, transfer, or adjustment)
**Last Updated**: 2026-03-31

---

## Overview

`StockMovementLine` stores one row per item in a stock movement. Each line captures the physical item, quantity breakdown (cartons/inners/units), unit price, and calculated totals. For transfers, the unit price is resolved from `BO_RawItemPrice` at time of creation and does not change if prices are updated later.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | Integer | PK, NOT NULL | Primary key, auto-increment |
| `StockMovementId` | Integer | FK, NOT NULL | FK → StockMovement.Id. Parent movement record |
| `PhysicalItemId` | Integer | FK, NOT NULL | FK → PhysicalItem.Id. The item being moved |
| `Description` | NVarChar(255) | NULL | Snapshot of item description at time of creation |
| `QtyOfCases` | Integer | NULL | Number of cartons/cases |
| `QtyOfInners` | Integer | NULL | Number of inners |
| `QtyOfLoose` | Integer | NULL | Number of loose/individual units |
| `QtyTotal` | Integer | NOT NULL | Calculated total: (QtyOfCases x CartonQty x InnerQty) + (QtyOfInners x InnerQty) + QtyOfLoose |
| `UnitPrice` | Decimal(18,5) | NULL | Price per unit from BO_RawItemPrice at time of save |
| `NetAmount` | Decimal(18,4) | NULL | QtyTotal x UnitPrice |
| `SyncedAt` | DateTime | NULL | Timestamp of last sync to downstream systems (null until synced) |

---

## Key Constraints

### Primary Key
- `Id` — Unique identifier

### Foreign Keys
- `StockMovementId` → `StockMovement`.`Id`
- `PhysicalItemId` → `PhysicalItem`.`Id`

---

## Relationships

### Tables This Table References
- **StockMovement** — Parent movement record
  - Join: `StockMovementLine.StockMovementId = StockMovement.Id`
- **PhysicalItem** — The physical item
  - Join: `StockMovementLine.PhysicalItemId = PhysicalItem.Id`

---

## Common Query Patterns

### Get Line Items for a Movement
```sql
SELECT
    sml.Id,
    sml.Description,
    sml.QtyOfCases,
    sml.QtyOfInners,
    sml.QtyOfLoose,
    sml.QtyTotal,
    sml.UnitPrice,
    sml.NetAmount
FROM {StockMovementLine} sml
WHERE sml.StockMovementId = @StockMovementId
```

### Get Line Count and Total for a Movement
```sql
SELECT
    sml.StockMovementId,
    COUNT(*) AS LineCount,
    SUM(sml.NetAmount) AS TotalNetAmount
FROM {StockMovementLine} sml
GROUP BY sml.StockMovementId
```

---

## Notes for OutSystems

- Use `{StockMovementLine}` in Advanced SQL
- `UnitPrice` is frozen at creation time — does not update when BO_RawItemPrice changes
- `QtyTotal` is pre-calculated and stored, not computed at query time
- `Description` is a snapshot — item name may have changed since creation

---

## Related Tables

- [StockMovement](../StockMovement/README.md) — Parent movement
- [PhysicalItem](../PhysicalItem/README.md) — The physical item

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-31 | Initial documentation from PRD 1.3 | Claude |
