# Table: LogicalItemUsage

**OutSystems Entity**: LogicalItemUsage
**Module**: Sales_UI (Stock)
**Database Table**: [dbo].[LogicalItemUsage]
**Purpose**: Stores daily sales/usage data per logical item per site — Net amounts and quantities by operation type
**Last Updated**: 2026-03-21

---

## Overview

`LogicalItemUsage` holds daily aggregated sales data for each logical item at a site. Each row represents one logical item's usage for a single site on a single calendar date. Contains Net amounts and quantities broken down by operation type (Sales, Crew, Manager, Discount, Refund, Promo, Waste).

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key, auto-increment |
| `SiteId` | Long Integer | FK to Site |
| `CalendarDate` | Date | Business/calendar date |
| `LogicalItemId` | Long Integer | FK to LogicalItem |

### Net Amount Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `SalesNetAmt` | Decimal | Net sales amount |
| `CrewNetAmt` | Decimal | Crew/employee meal net amount |
| `ManagerNetAmt` | Decimal | Manager meal net amount |
| `DiscountNetAmt` | Decimal | Discount net amount |
| `RefundNetAmt` | Decimal | Refund net amount |
| `PromoNetAmt` | Decimal | Promotion net amount |
| `WasteNetAmt` | Decimal | Waste net amount |

### Quantity Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `SalesQty` | Decimal | Sales quantity |
| `CrewQty` | Decimal | Crew/employee meal quantity |
| `ManagerQty` | Decimal | Manager meal quantity |
| `DiscountQty` | Decimal | Discount quantity |
| `RefundQty` | Decimal | Refund quantity |
| `PromoQty` | Decimal | Promotion quantity |
| `WasteQty` | Decimal | Waste quantity |

---

## Relationships

### Tables This Table References
- **LogicalItem** - Master logical item record
  - Join: `LogicalItemUsage.LogicalItemId = LogicalItem.Id`
- **Site** - Site reference
  - Join: `LogicalItemUsage.SiteId = Site.Id`

---

## Common Query Patterns

### Get Usage for a Site and Date
```sql
SELECT
    liu.LogicalItemId,
    liu.SalesNetAmt,
    liu.SalesQty,
    liu.CrewNetAmt,
    liu.WasteNetAmt
FROM {LogicalItemUsage} liu
WHERE liu.SiteId = @SiteId
  AND liu.CalendarDate = @Date
```

### Join to LogicalItem for Names
```sql
SELECT
    li.ItemName,
    li.WrinNumber,
    liu.SalesNetAmt,
    liu.SalesQty
FROM {LogicalItemUsage} liu
INNER JOIN {LogicalItem} li ON liu.LogicalItemId = li.Id
WHERE liu.SiteId = @SiteId
  AND liu.CalendarDate = @Date
```

---

## Comparison to ProductSalesByOperation

| Feature | LogicalItemUsage | ProductSalesByOperation |
|---------|-----------------|----------------------|
| Granularity | Logical item (grouped) | Individual product menu item |
| Join for name | LogicalItem.ItemName | ProductMenu.Name |
| Join for code | LogicalItem.WrinNumber | ProductMenu.ProductId |
| Has RefundNetAmt/RefundQty | Yes | Check docs |
| Filtering | SiteId + CalendarDate | SiteId + CalendarDate |

---

## Notes for OutSystems

- **Module**: `Sales_UI` (Stock section)
- **One row per LogicalItem per Site per Date** — pre-aggregated daily data
- **Column naming**: `*NetAmt` for dollar amounts, `*Qty` for quantities
- **No PosId/Pod filtering needed** — already aggregated at site level
- **Similar structure to ProductSalesByOperation** but at logical item level

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-21 | Initial documentation created from OutSystems entity screenshot | Claude |
