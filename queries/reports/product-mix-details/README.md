# Product Mix Details

## Purpose
Detail-level product mix report for a single site and date. Each row is an individual product showing sales breakdown (Sold, Promo, Discount, EmpMeals, MgrMeals, Waste, Total). Supports Dollar/Quantity view toggle.

## Tables Used
- **ProductSalesByOperation** - Source data (rollup of SalesFact by product)
- **ProductMenu** - Product Code (ProductId) and Name

## Parameters

| Parameter | Type | Expand Inline | Description |
|-----------|------|---------------|-------------|
| SiteId | Long Integer | No | Single site |
| Date | Date | No | Single business date |
| SelectedView | Text | No | 'D' = Dollars, 'Q' = Quantity |

## Output Structure

| Column | Type | Description |
|--------|------|-------------|
| Code | Long Integer | ProductMenu.ProductId |
| Name | Text | Product name (or 'Total' for total row) |
| Sold | Decimal | Sales amount/quantity |
| Promo | Decimal | Promo amount/quantity |
| Discount | Decimal | Discount amount/quantity |
| EmpMeals | Decimal | Employee meals amount/quantity |
| MgrMeals | Decimal | Manager meals amount/quantity |
| Waste | Decimal | Waste amount/quantity |
| Total | Decimal | Total amount/quantity |
| IsTotal | Integer | 0 = detail row, 1 = total row |

## OutSystems JSON Structure Definition
```json
[
  { "Name": "Code", "Type": "LongInteger" },
  { "Name": "Name", "Type": "Text" },
  { "Name": "Sold", "Type": "Decimal" },
  { "Name": "Promo", "Type": "Decimal" },
  { "Name": "Discount", "Type": "Decimal" },
  { "Name": "EmpMeals", "Type": "Decimal" },
  { "Name": "MgrMeals", "Type": "Decimal" },
  { "Name": "Waste", "Type": "Decimal" },
  { "Name": "Total", "Type": "Decimal" },
  { "Name": "IsTotal", "Type": "Integer" }
]
```

## Version History
| Version | Date | Changes |
|---------|------|---------|
| v1.0 | 2026-02-10 | Initial build |
