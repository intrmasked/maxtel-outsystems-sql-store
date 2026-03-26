# Table: PhysicalItem

**OutSystems Entity**: PhysicalItem
**Module**: Stock (StockV2 schema)
**Database Table**: [dbo].[PhysicalItem]
**Purpose**: Physical representation of stock items — stores unit names and portions-per-unit conversion factors
**Last Updated**: 2026-03-25

---

## Overview

`PhysicalItem` represents the physical form of a stock item (e.g., "Pattie", "Litre", "Tube", "Each"). Multiple physical items can map to one logical item. The `DefaultPhysicalItemId` on `LogicalItem` points to the primary physical item used for display unit conversion.

Key fields used by Raw Stock: `UnitName` (display label) and `PortionsPerUnit` (conversion factor from portions to display units).

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | Integer | PK, NOT NULL | Primary key, auto-increment |
| `BO_RawItemId` | Long Integer | FK | FK to back-office raw item |
| `ConceptId` | Long Integer | NOT NULL | Concept/brand identifier |
| `WrinNumber` | Text | NOT NULL | WRIN (Worldwide Restaurant Item Number) |
| `ItemName` | Text | NOT NULL | Display name of the physical item |
| `UnitsInCarton` | Integer | NULL | Number of units per carton |
| `UnitsInInners` | Integer | NULL | Number of units per inner pack |
| `LastSyncedAt` | DateTime | NULL | Last sync timestamp |
| `SupplierId` | Long Integer | FK, NULL | FK to Supplier |
| `LogicalItemId` | Integer | FK | FK → LogicalItem. Many physicals per logical |
| `PortionsPerUnit` | Decimal | NOT NULL | Portions per unit. Used to convert: displayUnits = portions / PortionsPerUnit |
| `UnitName` | Text | NOT NULL | Display label for one unit, e.g. "Pattie", "Litre", "Tube", "Each" |

---

## Key Constraints

### Primary Key
- `Id` — Unique identifier

### Foreign Keys
- `LogicalItemId` → `LogicalItem`.`Id`
- `SupplierId` → `Supplier`.`Id`

---

## Relationships

### Tables That Reference This Table
- **LogicalItem** — via `LogicalItem.DefaultPhysicalItemId = PhysicalItem.Id`
  - One LogicalItem points to one default PhysicalItem for display

### Tables This Table References
- **LogicalItem** — via `PhysicalItem.LogicalItemId = LogicalItem.Id`
  - Many physical items per logical item

---

## Portions Conversion

All StockPeriodBalance quantities are stored in portions. Convert for display:

```
displayUnits = storedPortions / PortionsPerUnit
```

Example: If PortionsPerUnit = 10 and OpenQty = 50, display as 5.0 units.

---

## Common Query Patterns

### Get Unit Info for a Logical Item
```sql
SELECT PI.UnitName, PI.PortionsPerUnit
FROM {PhysicalItem} PI
WHERE PI.Id = @DefaultPhysicalItemId
```

### Join from LogicalItem
```sql
SELECT LI.ItemName, PI.UnitName, PI.PortionsPerUnit
FROM {LogicalItem} LI
JOIN {PhysicalItem} PI ON LI.DefaultPhysicalItemId = PI.Id
```

---

## Notes for OutSystems

- Use `{PhysicalItem}` in Advanced SQL
- **Read-only** reference table — synced from back-office
- `PortionsPerUnit` should never be zero (would cause divide-by-zero)
- If `LogicalItem.DefaultPhysicalItemId` is null, exclude the row from Raw Stock display

---

## Related Tables

- [LogicalItem](../LogicalItem/README.md) — Parent logical grouping
- [StockPeriodBalance](../StockPeriodBalance/README.md) — Uses PortionsPerUnit for display conversion

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-25 | Initial documentation from spec + OutSystems entity screenshot | Claude |
