# Recipe For Logical Item

## Purpose
Given a LogicalItem (ingredient), find all menu items that use it in their recipe and cross-reference against actual sales for a given site and date. Powers the "Recipe For Logical" slideover panel showing which products consumed a specific ingredient on a given day.

## How It Works
1. **InputVar CTE** — Binds all 4 parameters (OutSystems Lazy Parser fix)
2. **RecipeItems** — Walks the chain: `LogicalItem → BO_RawIngredient → BO_Recipe → BO_MenuItem → ProductMenu`. Groups by menu item and SUMs `BRI.Qty` in case an ingredient appears multiple times in one recipe.
3. **Final SELECT** — LEFT JOINs to `ProductSalesByOperation` for actual sales. Products with no sales appear with NULL `ProductQtyUsed` and `QtyUsed`.

## Join Chain
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
| `MIN` | Text | Menu Item Number |
| `MenuItemName` | Text | BO_MenuItem.LONGNAME |
| `ProductQtyUsed` | Decimal | Sales quantity (NULL if no sales) |
| `ItemsPerProduct` | Decimal | How many of this ingredient per product (SUM of BRI.Qty) |
| `QtyUsed` | Decimal | ProductQtyUsed * ItemsPerProduct (NULL if no sales) |

## Tables Used
- `BO_RawIngredient` — Recipe ingredients (links raw items to recipes)
- `BO_Recipe` — Recipe definitions (links to menu items)
- `BO_MenuItem` — Menu item master (MIN, LONGNAME)
- `ProductMenu` — Product menu catalog (bridges to sales data)
- `ProductSalesByOperation` — Actual sales data (LEFT JOIN)
- `LogicalItem` — Logical item master (input filter)

## Important Notes
- LEFT JOIN on ProductSalesByOperation is intentional — products with no sales still appear
- QtyUsed is NULL (not 0) when there are no sales — intentional per business requirement
- IsDeleted = 0 filters on both BO_Recipe and BO_RawIngredient
