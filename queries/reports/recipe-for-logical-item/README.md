# Recipe For Logical Item

## Purpose
Given a LogicalItem (ingredient), find all menu items that use it in their recipe and cross-reference against actual sales for a given site and date. Powers the "Recipe For Logical" slideover panel showing which products consumed a specific ingredient on a given day.

Handles two ingredient paths:
- **Path A (Direct)**: Menu items that directly contain this logical item as a raw ingredient
- **Path B (Combo)**: Menu items (combos) that contain sub-items which use this logical item

## How It Works
1. **InputVar CTE** — Binds all 4 parameters (OutSystems Lazy Parser fix)
2. **RecipeItems (UNION ALL)** — Two paths:
   - **Path A**: `BO_Recipe → BO_RawIngredient → LogicalItem` (direct ingredients)
   - **Path B**: `BO_Recipe → BO_MenuIngredient → BO_MenuItem → BO_Recipe → BO_RawIngredient → LogicalItem` (combo sub-items, one level deep)
3. **AggregatedRecipe** — Merges both paths, SUMs ItemsPerProduct per menu item (same product may appear in both paths)
4. **WithSales** — LEFT JOINs to `ProductSalesByOperation` for actual sales. Products with no sales appear with NULL `ProductQtyUsed` and `QtyUsed`.
5. **Final SELECT** — Data rows + Totals row (MIN = 'Total', sums QtyUsed)

## Join Chain

### Path A (Direct)
```
LogicalItem (LI)
  ↓ LI.BO_RawItemId = BRI.BORawItemId
BO_RawIngredient (BRI)
  ↓ BRI.BORecipeId = BR.Id
BO_Recipe (BR)
  ↓ BR.BOMenuItemId = BM.Refkey
BO_MenuItem (BM)
  ↓ BM.MIN = PM.ProductId + ConceptId
ProductMenu (PM)
  ↓ PM.Id = PSBO.ProductMenuId (LEFT JOIN)
ProductSalesByOperation (PSBO)
```

### Path B (Combo — one level deep)
```
BO_MenuItem (BM) — parent combo item
  ↓ BR.BOMenuItemId = BM.Refkey
BO_Recipe (BR)
  ↓ BMI.BORecipeId = BR.Id
BO_MenuIngredient (BMI) — combo sub-item reference
  ↓ BMI.MIN = BM2.MIN + ConceptId
BO_MenuItem (BM2) — sub-item
  ↓ BR2.BOMenuItemId = BM2.Refkey
BO_Recipe (BR2) — sub-item's recipe
  ↓ BRI2.BORecipeId = BR2.Id
BO_RawIngredient (BRI2) — sub-item's raw ingredient
  ↓ LI.BO_RawItemId = BRI2.BORawItemId
LogicalItem (LI)
```

## Parameters

| Parameter | Type | Expand Inline | Description |
|-----------|------|--------------|-------------|
| `LogicalItemId` | Integer | No | The logical item to look up recipes for |
| `SiteId` | Integer | No | Site to check sales against |
| `CalendarDate` | Date | No | Date to check sales against |
| `ConceptId` | Integer | No | Concept/brand identifier |

## Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `MIN` | Text | Menu Item Number (or 'Total' for totals row) |
| `MenuItemName` | Text | BO_MenuItem.LONGNAME (empty for totals row) |
| `ProductQtyUsed` | Decimal | Sales quantity (NULL if no sales, NULL for totals row) |
| `ItemsPerProduct` | Decimal | Logical item qty per product — SUM of recipe qty across paths (NULL for totals row) |
| `QtyUsed` | Decimal | ProductQtyUsed × ItemsPerProduct (NULL if no sales; sum of all rows for totals row) |

## Tables Used
- `BO_RawIngredient` — Recipe ingredients (links raw items to recipes)
- `BO_Recipe` — Recipe definitions (links to menu items)
- `BO_MenuItem` — Menu item master (MIN, LONGNAME)
- `BO_MenuIngredient` — Combo sub-item references (links menu items as ingredients)
- `ProductMenu` — Product menu catalog (bridges to sales data)
- `ProductSalesByOperation` — Actual sales data (LEFT JOIN)
- `LogicalItem` — Logical item master (input filter)

## Important Notes
- LEFT JOIN on ProductSalesByOperation is intentional — products with no sales still appear
- QtyUsed is NULL (not 0) when there are no sales — intentional per business requirement
- IsDeleted = 0 filters on BO_Recipe, BO_RawIngredient, and BO_MenuIngredient
- Path B multiplier: `BMI.Qty * BRI2.Qty` (combo qty × sub-item recipe qty)
- Totals row: MIN = 'Total', sums QtyUsed across all data rows
- Combo recursion is one level only (spec requirement)
