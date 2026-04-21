# Table: DayParts

**OutSystems Entity**: DayParts
**Module**: Stock (StockV2 schema)
**Purpose**: Defines the shifts within a working day — Overnight, Breakfast, Day, Night
**Last Updated**: 2026-04-21

---

## Overview

`DayParts` defines the shift structure for a concept/brand. Each workday has exactly four shifts. Used by `RawWasteCount` to track waste per shift and by display queries to build shift-based cross-tab columns.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | Long Integer | PK, NOT NULL | Primary key, auto-increment |
| `ConceptId` | Long Integer | NOT NULL | Concept/brand identifier |
| `Order` | Integer | NOT NULL | Display order (1=Overnight, 2=Breakfast, 3=Day, 4=Night) |
| `Label` | Text | NOT NULL | Shift name: "Overnight", "Breakfast", "Day", "Night" |
| `StartTime` | Time | NOT NULL | Shift start time |
| `EndTime` | Time | NOT NULL | Shift end time |

---

## Key Constraints

### Primary Key
- `Id` — Unique identifier

### Logical Key
- (`ConceptId`, `Order`) — One shift per position per concept

---

## Standard Shift Structure

| Order | Label | Typical Times |
|-------|-------|---------------|
| 1 | Overnight | ~00:00 – 06:00 |
| 2 | Breakfast | ~06:00 – 10:30 |
| 3 | Day | ~10:30 – 17:00 |
| 4 | Night | ~17:00 – 00:00 |

---

## Common Query Patterns

### Get All Shifts for a Concept
```sql
SELECT Id, Label, [Order], StartTime, EndTime
FROM {DayParts}
WHERE ConceptId = @ConceptId
ORDER BY [Order]
```

---

## Notes for OutSystems

- Use `{DayParts}` in Advanced SQL
- `Order` is a reserved word in SQL — use `[Order]` in queries
- Read-only reference table
- Every workday has exactly 4 shifts — no partial days

---

## Related Tables

- [RawWasteCount](../RawWasteCount/README.md) — Child: waste per item per shift

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-04-21 | Initial documentation from Raw Waste PRD | Claude |
