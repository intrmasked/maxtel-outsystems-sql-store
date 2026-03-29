# Table: LogicalItem

**OutSystems Entity**: LogicalItem
**Module**: Sales_UI (Stock)
**Database Table**: [dbo].[LogicalItem]
**Purpose**: Master list of logical (grouped) menu items — maps raw BO items to logical product groupings
**Last Updated**: 2026-03-25

---

## Overview

`LogicalItem` represents a logical grouping of raw menu items. Each logical item has a name, a WRIN number, and links back to a `BO_RawItemId` and `ConceptId`. Used to aggregate product sales at a higher "logical" level rather than individual raw items.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key, auto-increment |
| `BO_RawItemId` | Long Integer | FK to raw back-office item |
| `ConceptId` | Long Integer | Concept/brand identifier |
| `WrinNumber` | Text | WRIN (Worldwide Restaurant Item Number) |
| `ItemName` | Text | Display name of the logical item |
| `LastSyncedAt` | Date Time | Last sync timestamp |
| `DefaultPhysicalItemId` | Long Integer | FK → PhysicalItem. Used to resolve UnitName and PortionsPerUnit for display |
| `ItemType` | Text | Item category. Values: Food, Paper, Other. Used for Product Type filter |

---

## Relationships

### Tables That Reference This Table
- **LogicalItemUsage** — Sales data per logical item per site/date
  - Join: `LogicalItemUsage.LogicalItemId = LogicalItem.Id`
- **StockPeriodBalance** — Stock balance per logical item per period
  - Join: `StockPeriodBalance.LogicalItemId = LogicalItem.Id`
- **PhysicalItem** — Physical representations of this logical item
  - Join: `PhysicalItem.LogicalItemId = LogicalItem.Id`

### Tables This Table References
- **PhysicalItem** — Default physical item for display conversion
  - Join: `LogicalItem.DefaultPhysicalItemId = PhysicalItem.Id`
- **CentralStockItem** — Central reference data (count frequency, etc.)
  - Join: `LogicalItem.ConceptId = CentralStockItem.ConceptId AND LogicalItem.WrinNumber = CentralStockItem.WrinNumberClean`

---

## Common Query Patterns

### Get Logical Item Details
```sql
SELECT Id, ItemName, WrinNumber, ConceptId
FROM {LogicalItem}
WHERE Id = @LogicalItemId
```

### Join to LogicalItemUsage
```sql
SELECT
    li.ItemName,
    li.WrinNumber,
    liu.SalesNetAmt,
    liu.SalesQty
FROM {LogicalItem} li
INNER JOIN {LogicalItemUsage} liu ON liu.LogicalItemId = li.Id
WHERE liu.SiteId = @SiteId
  AND liu.CalendarDate = @Date
```

---

## Notes for OutSystems

- **Module**: `Sales_UI` (Stock section)
- **ItemName** = Display name for reports
- **WrinNumber** = WRIN code (standard McDonald's item identifier)
- **BO_RawItemId** = Links back to raw back-office item data
- **Read Only**: Reference/master data table

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-21 | Initial documentation created from OutSystems entity screenshot | Claude |
| 2026-03-25 | Added ItemType column, DefaultPhysicalItemId description, relationships to StockPeriodBalance/PhysicalItem/CentralStockItem | Claude |
