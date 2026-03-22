# Table: BO_MenuIngredient

**OutSystems Entity**: BO_MenuIngredient
**Database Table**: [dbo].[BO_MenuIngredient]
**Purpose**: Combo sub-item records — links menu items as ingredients within a recipe (e.g., a combo meal containing a burger + fries)
**Last Updated**: 2026-03-22

---

## Overview

`BO_MenuIngredient` stores menu-level ingredients within a recipe (`BO_Recipe`). Unlike `BO_RawIngredient` which links to raw/logical items, `BO_MenuIngredient` links to other menu items (`BO_MenuItem` via `MIN`). This is how combo meals reference their sub-items.

To resolve a `BO_MenuIngredient` to its logical items, you must recurse one level: follow the sub-item's `MIN` to its own `BO_MenuItem → BO_Recipe → BO_RawIngredient → LogicalItem`.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Integer | Primary key |
| `BORecipeId` | Integer | FK to BO_Recipe (parent recipe) |
| `MIN` | Text | Menu Item Number of the sub-item |
| `Qty` | Decimal | Quantity of this sub-item per parent product |
| `IsWaste` | Boolean | Whether this is a waste ingredient |
| `BOMenuItemId` | Integer | FK to BO_MenuItem |
| `IsDeleted` | Boolean | Soft delete flag |

---

## Relationships

### Tables This Table References
- **BO_Recipe** — Parent recipe containing this sub-item
  - Join: `BO_MenuIngredient.BORecipeId = BO_Recipe.Id`
- **BO_MenuItem** — The sub-item menu item (via MIN)
  - Join: `BO_MenuIngredient.MIN = BO_MenuItem.MIN` (+ ConceptId filter on BO_MenuItem)

### Tables That Reference This Table
- None directly — this is a leaf in the combo chain

---

## Common Query Patterns

### Find Combo Sub-Items for a Recipe
```sql
SELECT BMI.MIN, BMI.Qty
FROM {BO_MenuIngredient} BMI
WHERE BMI.BORecipeId = @RecipeId
  AND BMI.IsDeleted = 0
```

### Resolve Combo Sub-Items to Logical Items (One Level Deep)
```sql
-- Path B: BO_MenuIngredient → BO_MenuItem → BO_Recipe → BO_RawIngredient → LogicalItem
SELECT BMI.Qty * BRI2.Qty AS TotalQty, LI.Id AS LogicalItemId
FROM {BO_MenuIngredient} BMI
INNER JOIN {BO_MenuItem} BM2 ON BMI.MIN = BM2.MIN AND BM2.ConceptId = @ConceptId
INNER JOIN {BO_Recipe} BR2 ON BR2.BOMenuItemId = BM2.Refkey
INNER JOIN {BO_RawIngredient} BRI2 ON BRI2.BORecipeId = BR2.Id AND BRI2.IsDeleted = 0
INNER JOIN {LogicalItem} LI ON LI.BO_RawItemId = BRI2.BORawItemId AND LI.ConceptId = @ConceptId
WHERE BMI.IsDeleted = 0
  AND BR2.IsDeleted = 0
```

---

## Notes for OutSystems
- **No ConceptId column** — filter through the joined `BO_MenuItem` instead
- **IsDeleted = 0** filter required — always exclude soft-deleted records
- **Qty** = multiplier for this sub-item (e.g., 2 means two of this sub-item per parent)
- **One level recursion only** — combos are not expected to contain other combos

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-22 | Initial documentation created from schema diagram | Claude |
