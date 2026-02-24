# Table: BO_MenuItem

**OutSystems Entity**: BO_MenuItem
**Module**: People_CS
**Database Table**: [dbo].[BO_MenuItem]
**Purpose**: Back Office menu item master data — used to classify products (e.g., IsMcCafe) and filter SalesFact by menu item type
**Last Updated**: 2026-02-24

---

## Overview

`BO_MenuItem` is the back office menu item catalog from the `People_CS` module. It stores product names, classification fields, tax details, and flags like `IsMcCafe` and `BrandType`. This table is joined to `SalesFact` (via `ProductMenuId → BO_MenuItem.Refkey` or via `ProductMenu`) to filter sales by product category.

> [!IMPORTANT]
> This table lives in the `People_CS` module, not `Sales_CS`. Use `{BO_MenuItem}` in OutSystems Advanced SQL when referencing from the correct module context.

---

## Table Structure

### Identity & Reference Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Refkey` | Long Integer | Primary key / reference key |
| `ConceptId` | Long Integer | Concept/brand identifier |
| `MIN` | Text | Menu Item Number (product code) |
| `SHORTNAME` | Text | Short display name |
| `LONGNAME` | Text | Long display name |
| `ALTNAME` | Text | Alternate name |
| `Current_BOMenuItemPriceId` | Long Integer | FK to current price record |

### Classification & Grouping

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `FAMILYGROUP` | Text | Top-level product family group |
| `SUBFAMILYGROUP` | Text | Sub-family within family group |
| `DISPLAYGROUP` | Text | Display grouping |
| `DAYPART` | Text | Day part classification |
| `INGREDIENTCLASS` | Text | Ingredient classification |
| `FORCECAT` | Text | Force category |
| `TYPE` | Text | Item type |
| `LSM` | Text | Local Store Marketing category |
| `NATPROMO` | Text | National promotion flag/code |

### Sales Flags

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `DISPWASTE` | Boolean/Text | Display waste flag |
| `ADDONSALES` | Boolean/Text | Add-on sales flag |
| `ADDONPRIORITY` | Integer | Add-on priority order |
| `SUGGSELL` | Boolean/Text | Suggested sell flag |

### Tax Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `TAX_EATIN` | Decimal | Eat-in tax rate |
| `TAX_TAKEOUT` | Decimal | Takeout tax rate |
| `TAX_OTHER` | Decimal | Other tax rate |
| `TAXCHAIN_EATIN` | Text | Eat-in tax chain |
| `TAXCHAIN_TAKEOUT` | Text | Takeout tax chain |
| `TAXCHAIN_OTHER` | Text | Other tax chain |

### Special Product Flags

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `PROD_SPECIAL_TOY` | Boolean | Is a toy/special product |
| `PROD_SPECIAL_NONPROD` | Boolean | Is a non-product item |
| `PROD_SPECIAL_GIFTCERT` | Boolean | Is a gift certificate |

### USR (User-Defined) Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `USR_CYT_Std_build` | Text | CYT standard build flag |
| `USR_MISF` | Text | MISF flag |
| `USR_EquivalentMIN` | Text | Equivalent menu item number |
| `USR_CoreMenu_Burger` | Boolean | Core menu burger flag |
| `USR_CYT_Burger` | Boolean | CYT burger flag |
| `USR_CYTitem` | Boolean | Is a CYT item |
| `USR_HappyMeal` | Boolean | Is a Happy Meal item |
| `USR_IWitem` | Boolean | Is an IW item |
| `USR_AS400_no` | Text | AS400 item number |
| `USR_SSPitem` | Boolean | Is an SSP item |
| `USR_btrShow` | Boolean | Show in BTR flag |
| `USR_btrUOMA` | Text | BTR Unit of Measure A |
| `USR_btrHoldTimeA` | Integer | BTR hold time A |
| `USR_btrUOMB` | Text | BTR Unit of Measure B |
| `USR_btrHoldTimeB` | Integer | BTR hold time B |

### Key Flag Columns (Most Used in Queries)

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `IsMcCafe` | Boolean | **True if item is a McCafe product** — use to filter McCafe sales |
| `BrandType` | Text | Brand type identifier |
| `UpdatedOn` | Date Time | Last update timestamp |
| `CreatedOn` | Date Time | Creation timestamp |

---

## Relationships

### How to Join to SalesFact

`BO_MenuItem` links to `SalesFact` via the `ProductMenu` table:

```sql
-- Step 1: Join ProductMenu to get the MIN (menu item number)
-- Step 2: Join BO_MenuItem on ProductMenu.ProductId = BO_MenuItem.MIN
FROM {SalesFact} sf
INNER JOIN {ProductMenu} pm ON sf.ProductMenuId = pm.Id
INNER JOIN {BO_MenuItem} mi ON pm.ProductId = mi.MIN
WHERE mi.IsMcCafe = 1
```

> [!NOTE]
> The join key is `ProductMenu.ProductId = BO_MenuItem.MIN` (both are the product code).
> Always verify this join key against live data if results seem off.

---

## Common Query Patterns

### Filter McCafe Sales from SalesFact
```sql
-- Get McCafe sales for a site and date
-- CRITICAL: Null out all unused dimensions in SalesFact to prevent double-counting
SELECT
    sf.CalendarDate,
    SUM(sf.NetAmount) AS McCafeSales,
    SUM(sf.TransactionCount) AS McCafeTransactions
FROM {SalesFact} sf
INNER JOIN {ProductMenu} pm ON sf.ProductMenuId = pm.Id
INNER JOIN {BO_MenuItem} mi ON pm.ProductId = mi.MIN
WHERE sf.SiteId = @SiteId
  AND sf.CalendarDate = @Date
  AND sf.DatePeriodDimensionId = 15
  AND mi.IsMcCafe = 1
  -- Mandatory dimension filters (null out unused dims)
  AND sf.TenderTypeId IS NULL
  AND sf.OperationId IS NULL
  AND sf.OperationKindId IS NULL
  AND sf.SWCCashDrawerId IS NULL
  AND sf.SaleTypeId IS NULL
  AND sf.ProductSaleTypeId = 1
  AND sf.PosId IS NOT NULL
  AND sf.PosId <> 0
GROUP BY sf.CalendarDate
```

### Check IsMcCafe Items
```sql
SELECT MIN, SHORTNAME, LONGNAME, IsMcCafe, BrandType, FAMILYGROUP
FROM {BO_MenuItem}
WHERE IsMcCafe = 1
ORDER BY MIN
```

---

## Notes for OutSystems

- **Module**: `People_CS` — must be referenced from a module that consumes `People_CS`
- **IsMcCafe** = The primary filter for McCafe product sales channel queries
- **BrandType** = May be used to distinguish McCafe vs core menu items
- **Join pattern**: `SalesFact → ProductMenu → BO_MenuItem` (via `MIN = ProductId`)
- **ProductMenuId IS NOT NULL** in SalesFact when a product is associated — filter accordingly
- **When filtering by IsMcCafe**: Set `ProductMenuId` in SalesFact to NOT NULL (don't set it IS NULL — you need the join)
- **All other unused dimensions in SalesFact must still be NULL** to prevent double-counting

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-02-24 | Initial documentation created from OutSystems entity screenshot | Claude |
