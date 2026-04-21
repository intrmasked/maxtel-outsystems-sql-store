# Table: LogicalItemSiteConfig

**OutSystems Entity**: LogicalItemSiteConfig
**Module**: Stock (StockV2 schema)
**Purpose**: Per-site configuration flags for logical items — controls which items are active and wasteable at each site
**Last Updated**: 2026-04-21

---

## Overview

`LogicalItemSiteConfig` stores per-site flags for each logical item. The `IsActive` and `IsWasteable` flags determine which items appear in the Raw Waste entry panel and detail views for a given site.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | Long Integer | PK, NOT NULL | Primary key, auto-increment |
| `LogicalItemId` | Long Integer | FK, NOT NULL | FK → LogicalItem |
| `SiteId` | Long Integer | FK, NOT NULL | FK → Site |
| `IsWasteable` | Boolean | NOT NULL | Whether this item is tracked for waste at this site |
| `IsActive` | Boolean | NOT NULL | Whether this item is active at this site |

---

## Key Constraints

### Primary Key
- `Id` — Unique identifier

### Foreign Keys
- `LogicalItemId` → `LogicalItem`.`Id`
- `SiteId` → `Site`.`Id`

### Logical Key
- (`LogicalItemId`, `SiteId`) — One config per item per site

---

## Relationships

### Tables This Table References
- **LogicalItem** — The item being configured
  - Join: `LogicalItemSiteConfig.LogicalItemId = LogicalItem.Id`
- **Site** — The site this config applies to
  - Join: `LogicalItemSiteConfig.SiteId = Site.Id`

---

## Common Query Patterns

### Get Wasteable Active Items for a Site
```sql
SELECT lisc.LogicalItemId
FROM {LogicalItemSiteConfig} lisc
WHERE lisc.SiteId = @SiteId
  AND lisc.IsActive = 1
  AND lisc.IsWasteable = 1
```

---

## Notes for OutSystems

- Use `{LogicalItemSiteConfig}` in Advanced SQL
- Both `IsActive = 1` AND `IsWasteable = 1` are required for Raw Waste inclusion
- Read-only from Raw Waste screens — configured elsewhere

---

## Related Tables

- [LogicalItem](../LogicalItem/README.md) — Parent: the logical item
- [Site](../Site/README.md) — Parent: the site

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-04-21 | Initial documentation from Raw Waste PRD | Claude |
