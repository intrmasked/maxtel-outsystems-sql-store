# Query: Product Mix List

**Purpose**: Product mix report showing Sold, Promo, Discount, Emp Meals, Mgr Meals, Waste, Total with CashTotal variance from SalesFact.

**Created**: 2026-02-08  
**Version**: 1.0  
**Status**: In Testing  

---

## Parameters

| Parameter | Type | OutSystems | Description |
|-----------|------|------------|-------------|
| `@SiteIds` | Text | **Expand Inline = YES** | Comma-separated Site IDs |
| `@StartDate` | Date | Expand Inline = No | Start of date range |
| `@EndDate` | Date | Expand Inline = No | End of date range |

---

## Data Sources

| Table | Purpose |
|-------|---------|
| `ProductSalesByOperation` | Rollup table with product mix amounts |
| `SalesFact` | CashTotal calculation (matches Cash->ProductSales) |
| `Site` | Site display names |

---

## Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `SiteName` | Text | Site name or "Site Total" / "Total" |
| `Date` | Date | Calendar date (NULL for totals) |
| `Sold` | Decimal | SalesGrossAmt sum |
| `Promo` | Decimal | PromoGrossAmt sum |
| `Discount` | Decimal | DiscountGrossAmt sum |
| `EmpMeals` | Decimal | CrewGrossAmt sum |
| `MgrMeals` | Decimal | ManagerGrossAmt sum |
| `Waste` | Decimal | WasteGrossAmt sum |
| `Total` | Decimal | TotalGrossAmt sum |
| `CashTotal` | Decimal | SalesFact.NetAmount (SalesFactTypeId=2) |
| `Variance` | Decimal | Total - CashTotal |
| `SortOrder` | Integer | For UI sorting |

---

## CashTotal Logic

```sql
-- CashTotal matches Cash->ProductSales screen
SUM(SalesFact.NetAmount) WHERE:
  - SalesFactTypeId = 2 (QtrHourSalesAndProductMix)
  - ProductSaleTypeId = 1 (Product Sales)
  - DatePeriodDimensionId = 15 (15-min intervals)
  - All other dimension IDs = NULL
```

---

## Row Types

| RowType | Description |
|---------|-------------|
| Detail | Individual Site + Date combination |
| Site Total | Sum for each site across date range |
| Total | Grand total for all sites |

---

## Usage

**OutSystems**: Add to Advanced SQL block with parameters as specified above.

**SSMS Testing**: Use `tests/test-ssms.sql` with STRING_SPLIT for comma-separated sites.
