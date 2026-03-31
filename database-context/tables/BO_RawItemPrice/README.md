# Table: BO_RawItemPrice

**OutSystems Entity**: BO_RawItemPrice
**Module**: People (People_CS)
**Purpose**: Historical unit prices for raw items, used to resolve current price at time of stock movement creation
**Last Updated**: 2026-03-31

---

## Overview

`BO_RawItemPrice` stores price history for raw items identified by ConceptId + WRIN. Each row has an `Effective` date — the most recent row with `Effective <= today` is the current price. Used by the transfers feature to resolve `UnitPrice` on `StockMovementLine` at save time.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Refkey` | NVarChar(50) | NULL | Internal reference key |
| `ConceptId` | Integer | FK, NOT NULL | FK → Concept.Id. Join to PhysicalItem.ConceptId |
| `WRIN` | NVarChar(50) | NOT NULL | Item identifier. Join to PhysicalItem.WRIN |
| `Value` | Decimal(18,5) | NOT NULL | Unit price |
| `Effective` | Date | NOT NULL | Date from which this price is in effect |

---

## Key Constraints

### Foreign Keys
- `ConceptId` → `Concept`.`Id` (via PhysicalItem.ConceptId)

### Logical Key
- (`ConceptId`, `WRIN`, `Effective`) — One price per item per effective date

---

## Relationships

### Tables This Table References
- **PhysicalItem** — Linked via ConceptId + WRIN
  - Join: `BO_RawItemPrice.ConceptId = PhysicalItem.ConceptId AND BO_RawItemPrice.WRIN = PhysicalItem.WRIN`

---

## Price Resolution Pattern

To get the **current price** for a PhysicalItem:

```sql
SELECT TOP 1 rip.Value
FROM {BO_RawItemPrice} rip
INNER JOIN {PhysicalItem} pi ON pi.ConceptId = rip.ConceptId AND pi.WRIN = rip.WRIN
WHERE pi.Id = @PhysicalItemId
  AND rip.Effective <= GETDATE()
ORDER BY rip.Effective DESC
```

This resolves the most recent price that has taken effect.

---

## Notes for OutSystems

- Use `{BO_RawItemPrice}` in Advanced SQL
- Price is resolved at save time and stored on StockMovementLine.UnitPrice
- Once stored on a line item, price does **not** update if BO_RawItemPrice changes
- Join through PhysicalItem using ConceptId + WRIN (not a direct FK)

---

## Related Tables

- [PhysicalItem](../PhysicalItem/README.md) — Linked via ConceptId + WRIN

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-31 | Initial documentation from PRD 1.3 | Claude |
