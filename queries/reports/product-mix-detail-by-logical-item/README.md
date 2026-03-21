# Product Mix Detail by Logical Item

## Purpose
Detail-level product mix report grouped by **logical item** for a single site and date. Each row represents one logical item from `LogicalItemUsage` joined to `LogicalItem` for name/WRIN. Supports Dollar (D) and Quantity (Q) view toggle. Includes a Total row.

## How It Works
1. **InputVar CTE** — Binds `@SelectedView` parameter (OutSystems Lazy Parser fix)
2. **ItemData** — Joins `LogicalItemUsage` to `LogicalItem`, aggregates by WrinNumber + ItemName. Computes both Dollar (`*NetAmt`) and Quantity (`*Qty`) columns. Total = sum of all operation types.
3. **AllRows** — UNION ALL of detail rows + Total row
4. **Final SELECT** — CASE toggle between Dollar and Quantity based on `@SelectedView`

## Difference from product-mix-details
| Feature | product-mix-details | This query |
|---------|-------------------|------------|
| Granularity | Individual product (ProductMenu) | Logical item (grouped) |
| Data table | ProductSalesByOperation | LogicalItemUsage |
| Name source | ProductMenu.Name | LogicalItem.ItemName |
| Code/ID | ProductMenu.ProductId | LogicalItem.WrinNumber |
| Has Refund column | No | Yes |

## Parameters

| Parameter | Type | Expand Inline | Description |
|-----------|------|--------------|-------------|
| `SiteId` | Long Integer | No | Single site ID |
| `Date` | Date | No | Business date |
| `SelectedView` | Text | No | `'D'` = Dollars, `'Q'` = Quantity |

## Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `WrinNumber` | Text | WRIN code (or 'Total' for total row) |
| `ItemName` | Text | Logical item name (or '' for total row) |
| `Sold` | Decimal | Sales amount or quantity |
| `Promo` | Decimal | Promotion amount or quantity |
| `Discount` | Decimal | Discount amount or quantity |
| `EmpMeals` | Decimal | Crew/employee meal amount or quantity |
| `MgrMeals` | Decimal | Manager meal amount or quantity |
| `Waste` | Decimal | Waste amount or quantity |
| `Refund` | Decimal | Refund amount or quantity |
| `Total` | Decimal | Sum of all operation types |

## Tables Used
- `LogicalItemUsage` — Daily usage data per logical item per site
- `LogicalItem` — Logical item master (WrinNumber, ItemName)

## Performance
- Simple query: single JOIN on pre-aggregated daily data
- Expected: < 200ms for single site/date
