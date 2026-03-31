# Table: MovementType

**OutSystems Entity**: MovementType
**Module**: Stock (Stock_CS)
**Purpose**: Enum/reference table for stock movement types
**Last Updated**: 2026-03-31

---

## Overview

`MovementType` is a small reference table that defines the types of stock movements. Used as a FK from `StockMovement.MovementTypeId`.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | Integer | PK, NOT NULL | Primary key |
| `Label` | NVarChar | NOT NULL | Display label |
| `Order` | Integer | NOT NULL | Sort order for UI |
| `Is_Active` | Boolean | NOT NULL | Whether this type is active |

---

## Static Data

| Id | Label | Order | Is_Active |
|----|-------|-------|-----------|
| 1 | Adjustment | 2 | true |
| 2 | Transfer | 3 | true |
| 3 | Delivery | 1 | true |

---

## Key Usage

- `MovementTypeId = 1` → Adjustment
- `MovementTypeId = 2` → **Transfer** (used for inter-store transfers)
- `MovementTypeId = 3` → Delivery

---

## Notes for OutSystems

- Use `{MovementType}` in Advanced SQL
- Small static table — safe to join without performance concerns
- For transfers, filter with `WHERE sm.MovementTypeId = 2`

---

## Related Tables

- [StockMovement](../StockMovement/README.md) — References via MovementTypeId

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-31 | Initial documentation from OutSystems screenshot | Claude |
