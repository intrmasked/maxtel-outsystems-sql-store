# Table: BO_RawIngredient

**OutSystems Entity**: BO_RawIngredient
**Database Table**: [dbo].[BO_RawIngredient]
**Purpose**: Recipe ingredient records — links raw items to recipes with quantity per serving
**Last Updated**: 2026-03-22

---

## Overview

`BO_RawIngredient` stores the individual ingredients that make up a recipe (`BO_Recipe`). Each row represents one raw ingredient in a recipe, with a quantity (`Qty`) indicating how much of that ingredient is used per product. Links to `LogicalItem` via `BORawItemId = LogicalItem.BO_RawItemId`.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key |
| `BORecipeId` | Long Integer | FK to BO_Recipe |
| `BORawItemId` | Long Integer | FK to raw item (matches LogicalItem.BO_RawItemId) |
| `WRIN` | Text | WRIN number (may differ from LogicalItem.WrinNumber — see warning below) |
| `Qty` | Decimal | Quantity of this ingredient per product |
| `IsDeleted` | Boolean | Soft delete flag |
| `IsMandatory` | Boolean | Whether ingredient is mandatory |

---

## Relationships

### Tables This Table References
- **BO_Recipe** — Parent recipe
  - Join: `BO_RawIngredient.BORecipeId = BO_Recipe.Id`
- **LogicalItem** — Links via raw item ID
  - Join: `BO_RawIngredient.BORawItemId = LogicalItem.BO_RawItemId`

---

## Common Query Patterns

### Find All Recipes Using a Logical Item
```sql
SELECT BRI.BORecipeId, BRI.Qty
FROM {BO_RawIngredient} BRI
INNER JOIN {LogicalItem} LI ON BRI.BORawItemId = LI.BO_RawItemId
WHERE LI.Id = @LogicalItemId
  AND BRI.IsDeleted = 0
```

---

## Notes for OutSystems
- **IsDeleted = 0** filter required — always exclude soft-deleted records
- **Qty** = amount of this ingredient per product serving
- **BORawItemId** links to `LogicalItem.BO_RawItemId` (NOT LogicalItem.Id)

> **WARNING: WRIN Column Mismatch**
> `BO_RawIngredient.WRIN` does NOT always match `LogicalItem.WrinNumber`.
> **NEVER filter on `BRI.WRIN = @WRIN`** — always join through `LogicalItem`:
> `LogicalItem.WrinNumber = @WRIN → LogicalItem.BO_RawItemId → BRI.BORawItemId`
> This was discovered during the recipe-for-logical-item query debugging (2026-03-25).

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-22 | Initial documentation created from OutSystems entity screenshot | Claude |
| 2026-03-25 | Added WRIN column + WARNING about WRIN mismatch with LogicalItem.WrinNumber | Claude |
