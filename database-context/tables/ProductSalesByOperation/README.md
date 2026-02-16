# Table: ProductSalesByOperation

**OutSystems Entity**: ProductSalesByOperation  
**Database Table**: [dbo].[ProductSalesByOperation]  
**Purpose**: Rollup table of SalesFact aggregated by operation - used for product mix reports  
**Last Updated**: 2026-02-16  

---

## Overview

ProductSalesByOperation is a pre-aggregated rollup of SalesFact data by operation. Each row represents a single product's sales data for a given Site/Date/ProductMenu combination. Use this table instead of SalesFact when you need product mix totals without transaction-level detail.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key, auto-increment |
| `Tenant_Id` | Long Integer | Multi-tenant identifier |
| `SiteId` | Long Integer | Foreign key to Site |
| `CalendarDate` | Date | Business date for the data |
| `DatePeriodDimensionId` | Long Integer | Date period dimension (15 = 15-min, 1440 = daily) |
| `ProductMenuId` | Long Integer | Foreign key to ProductMenu |

### Amount Columns (Gross)

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `TotalGrossAmt` | Decimal | Total gross amount (sum of all) |
| `TotalGrossB4DiscountAmt` | Decimal | Total gross before discounts |
| `SalesGrossAmt` | Decimal | Sales gross amount (Sold) |
| `PromoGrossAmt` | Decimal | Promotional gross amount |
| `DiscountGrossAmt` | Decimal | Discount gross amount |
| `CrewGrossAmt` | Decimal | Crew/Employee meals gross amount |
| `ManagerGrossAmt` | Decimal | Manager meals gross amount |
| `WasteGrossAmt` | Decimal | Waste gross amount |
| `RefundGrossAmt` | Decimal | Refund gross amount |

### Amount Columns (Net) — **Use these for reports**

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `TotalNetAmt` | Decimal | Total net amount (sum of all, excl. tax) |
| `SalesNetAmt` | Decimal | Sales net amount |
| `PromoNetAmt` | Decimal | Promotional net amount |
| `DiscountNetAmt` | Decimal | Discount net amount |
| `CrewNetAmt` | Decimal | Crew/Employee meals net amount |
| `ManagerNetAmt` | Decimal | Manager meals net amount |
| `WasteNetAmt` | Decimal | Waste net amount |
| `RefundNetAmt` | Decimal | Refund net amount |

### Before Discount Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `SalesGrossB4DiscountAmt` | Decimal | Sales before discount |
| `CrewGrossB4DiscountAmt` | Decimal | Crew meals before discount |
| `ManagerGrossB4DiscountAmt` | Decimal | Manager meals before discount |
| `DiscountGrossB4DiscountAmt` | Decimal | Discount before discount |
| `RefundGrossB4DiscountAmt` | Decimal | Refund before discount |
| `PromoGrossB4DiscountAmt` | Decimal | Promo before discount |
| `WasteGrossB4DiscountAmt` | Decimal | Waste before discount |

### Quantity Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `TotalQuantitySold` | Decimal | Total quantity sold |
| `SalesQuantity` | Decimal | Sales quantity |
| `CrewQuantity` | Decimal | Crew meals quantity |
| `ManagerQuantity` | Decimal | Manager meals quantity |
| `DiscountQuantity` | Decimal | Discount quantity |
| `RefundQuantity` | Decimal | Refund quantity |
| `PromoQuantity` | Decimal | Promo quantity |
| `WasteQuantity` | Decimal | Waste quantity |

| `AveragePrice` | Decimal | Average price per unit |

---

## Relationships

### Tables This Table References
- **Site** - Links via SiteId
  - Join: `ProductSalesByOperation.SiteId = Site.Id`
- **ProductMenu** - Links via ProductMenuId
  - Join: `ProductSalesByOperation.ProductMenuId = ProductMenu.Id`

---

## Common Query Patterns

### Get Product Mix Totals for Date Range
```sql
SELECT
    SiteId,
    CalendarDate,
    SUM(SalesGrossAmt) AS Sold,
    SUM(PromoGrossAmt) AS Promo,
    SUM(DiscountGrossAmt) AS Discount,
    SUM(CrewGrossAmt) AS EmpMeals,
    SUM(ManagerGrossAmt) AS MgrMeals,
    SUM(WasteGrossAmt) AS Waste,
    SUM(TotalGrossAmt) AS Total
FROM {ProductSalesByOperation}
WHERE SiteId = @SiteId
  AND CalendarDate BETWEEN @StartDate AND @EndDate
GROUP BY SiteId, CalendarDate
```

---

## Notes for OutSystems

- **Rollup Table**: Pre-aggregated data - faster than querying SalesFact directly
- **Sum Required**: Each row is a single product, must SUM for site/date totals
- **DatePeriodDimensionId**: Filter as needed (15 = 15-min intervals, 1440 = daily)
- **Use with SalesFact**: For variance reports, compare TotalGrossAmt to SalesFact.NetAmount
