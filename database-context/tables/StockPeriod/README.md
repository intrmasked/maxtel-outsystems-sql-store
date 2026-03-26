# Table: StockPeriod

**OutSystems Entity**: StockPeriod
**Module**: Stock (StockV2 schema)
**Database Table**: [dbo].[StockPeriod]
**Purpose**: One record per Site + Date representing a stock counting period
**Last Updated**: 2026-03-25

---

## Overview

`StockPeriod` tracks business-date-level stock periods per site. Each record represents one day of stock activity for a site. It is the parent for `StockPeriodBalance` rows (one per LogicalItem per period). Created automatically by the SyncListener when StoreWideClose fires, or manually via the Settings card.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | Integer | PK, NOT NULL | Primary key, auto-increment |
| `SiteId` | Integer | FK, NOT NULL | FK → Site. The site this period belongs to |
| `Date` | Date | NOT NULL | Business date for the stock period |
| `StockPeriodStatusId` | Integer | FK, DEFAULT 1 | FK → StockPeriodStatus. 1=Open, 2=Closed, 3=Locked |

---

## Key Constraints

### Primary Key
- `Id` — Unique identifier

### Foreign Keys
- `SiteId` → `Site`.`Id`
- `StockPeriodStatusId` → `StockPeriodStatus`.`Id`

### Unique Constraints
- (`SiteId`, `Date`) — One period per site per day

---

## Relationships

### Tables That Reference This Table
- **StockPeriodBalance** — One balance row per LogicalItem per StockPeriod
  - Join: `StockPeriodBalance.StockPeriodId = StockPeriod.Id`

### Tables This Table References
- **Site** — The site this period belongs to
  - Join: `StockPeriod.SiteId = Site.Id`

---

## StockPeriodStatus Reference

| Id | Label |
|----|-------|
| 1 | Open |
| 2 | Closed |
| 3 | Locked |

---

## Common Query Patterns

### Get Periods for Site in Date Range
```sql
SELECT Id, SiteId, Date, StockPeriodStatusId
FROM {StockPeriod}
WHERE SiteId = @SiteId
  AND Date BETWEEN @StartDate AND @EndDate
ORDER BY Date
```

---

## Notes for OutSystems

- **Read Only** from Raw Stock screens (created by SyncListener or Settings card)
- Use `{StockPeriod}` in OutSystems Advanced SQL
- Filtering by `SiteId` + `Date` range is the primary access pattern

---

## Related Tables

- [StockPeriodBalance](../StockPeriodBalance/README.md) — Child: one balance per logical item per period
- [Site](../Site/README.md) — Parent: the site

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-25 | Initial documentation from spec + OutSystems entity screenshot | Claude |
