# Table: CentralStockItem

**OutSystems Entity**: CentralStockItem
**Module**: Stock (StockV2 schema)
**Database Table**: [dbo].[CentralStockItem]
**Purpose**: Central reference data for stock items — provides count frequency, group defaults, and wasteable flags
**Last Updated**: 2026-03-25

---

## Overview

`CentralStockItem` is a central reference table that stores default configuration for stock items at the concept level. Joined to `LogicalItem` via `ConceptId` + `WrinNumberClean`. Provides the `DefaultCountPeriodId` used for the Count Frequency filter in Raw Stock screens.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | Integer | PK, NOT NULL | Primary key, auto-increment |
| `WrinNumber` | Text | NOT NULL | WRIN (Worldwide Restaurant Item Number). Original format (e.g. `01908-024`) |
| `WrinNumberClean` | Text | NULL | Cleaned WRIN — numeric only (e.g. `90000809`). **Join key with LogicalItem** |
| `ItemName` | Text | NOT NULL | Central item name |
| `UnitLabel` | Text | NULL | Unit label from central system |
| `UnitsInCarton` | Integer | NULL | Units per carton |
| `UnitsInInners` | Integer | NULL | Units per inner pack |
| `DefaultCountPeriodId` | Integer | FK, NULL | FK → CountPeriod. Drives Count Frequency filter (Daily, Weekly, Monthly) |
| `ConceptId` | Integer | NOT NULL | Concept/brand identifier. Join key with LogicalItem |
| `DefaultGroupId` | Integer | FK, NULL | FK → default stock group |
| `DefaultIsWasteable` | Boolean | DEFAULT false | Whether this item is wasteable by default |
| `CreatedOn` | DateTime | NOT NULL | Record creation timestamp |
| `UpdatedOn` | DateTime | NULL | Last update timestamp |
| `IsActive` | Boolean | DEFAULT true | Whether this central item is active |

---

## Key Constraints

### Primary Key
- `Id` — Unique identifier

### Unique Constraints
- (`ConceptId`, `WrinNumber`) — One central item per concept + WRIN
- (`ConceptId`, `WrinNumberClean`) — Used for join to LogicalItem

---

## Relationships

### Tables That Reference This Table
- **LogicalItem** — Joined via ConceptId + WrinNumberClean
  - Join: `LogicalItem.ConceptId = CentralStockItem.ConceptId AND LogicalItem.WrinNumber = CentralStockItem.WrinNumberClean`

---

## Common Query Patterns

### Join from LogicalItem
```sql
SELECT CSI.DefaultCountPeriodId
FROM {LogicalItem} LI
LEFT JOIN {CentralStockItem} CSI
  ON LI.ConceptId = CSI.ConceptId
  AND LI.WrinNumber = CSI.WrinNumberClean
```

### Filter by Count Frequency
```sql
WHERE CSI.DefaultCountPeriodId IN (@CountFrequencies)
```

---

## Notes for OutSystems

- Use `{CentralStockItem}` in Advanced SQL
- **Read-only** reference table
- Join to LogicalItem is on **two columns**: `ConceptId` + `WrinNumberClean` (not a simple FK)
- `DefaultCountPeriodId` maps to CountPeriod labels (Daily, Weekly, Monthly, etc.)

---

## Related Tables

- [LogicalItem](../LogicalItem/README.md) — Joined via ConceptId + WrinNumberClean

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-25 | Initial documentation from spec + OutSystems entity screenshot | Claude |
| 2026-03-30 | Added WrinNumberClean column. Join key changed from WrinNumber → WrinNumberClean. Changed JOIN → LEFT JOIN in query patterns. | Claude |
