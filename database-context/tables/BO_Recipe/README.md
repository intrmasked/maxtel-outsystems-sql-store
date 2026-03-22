# Table: BO_Recipe

**OutSystems Entity**: BO_Recipe
**Database Table**: [dbo].[BO_Recipe]
**Purpose**: Recipe definitions — links menu items to their ingredient lists
**Last Updated**: 2026-03-22

---

## Overview

`BO_Recipe` represents a recipe for a menu item (`BO_MenuItem`). Each recipe can have multiple ingredients via `BO_RawIngredient`. The `BOMenuItemId` links back to `BO_MenuItem.Refkey` to identify which menu item this recipe belongs to.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key |
| `Refkey` | Long Integer | Reference key |
| `BOMenuItemId` | Long Integer | FK to BO_MenuItem.Refkey |
| `IsDeleted` | Boolean | Soft delete flag |
| `ACTIONCODE` | Text | Action code |
| `ACTIVEDATEFROM` | Date Time | Recipe active from date |
| `ACTIVEDATETO` | Date Time | Recipe active until date |
| `BUILDINSTRUCTION` | Text | Build instructions |
| `CHOICEGROUP` | Text | Choice group |
| `COSTPRICE` | Decimal | Cost price |
| `CUSTOMIZABLE` | Boolean | Whether recipe is customizable |

---

## Relationships

### Tables This Table References
- **BO_MenuItem** — Parent menu item
  - Join: `BO_Recipe.BOMenuItemId = BO_MenuItem.Refkey`

### Tables That Reference This Table
- **BO_RawIngredient** — Ingredients in this recipe
  - Join: `BO_RawIngredient.BORecipeId = BO_Recipe.Id`

---

## Common Query Patterns

### Get Recipe for a Menu Item
```sql
SELECT BR.Id, BR.BOMenuItemId, BR.IsDeleted
FROM {BO_Recipe} BR
WHERE BR.BOMenuItemId = @BOMenuItemRefkey
  AND BR.IsDeleted = 0
```

### Full Chain: LogicalItem → RawIngredient → Recipe → MenuItem
```sql
SELECT BM.MIN, BM.LONGNAME, BRI.Qty
FROM {BO_RawIngredient} BRI
INNER JOIN {BO_Recipe} BR ON BRI.BORecipeId = BR.Id
INNER JOIN {BO_MenuItem} BM ON BR.BOMenuItemId = BM.Refkey
WHERE BRI.BORawItemId = @BORawItemId
  AND BR.IsDeleted = 0
  AND BRI.IsDeleted = 0
```

---

## Notes for OutSystems
- **IsDeleted = 0** filter required — always exclude soft-deleted recipes
- **BOMenuItemId** matches `BO_MenuItem.Refkey` (NOT BO_MenuItem.Id if different)
- Recipe → Ingredients is a one-to-many relationship via BO_RawIngredient

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-22 | Initial documentation created from OutSystems entity screenshot | Claude |
