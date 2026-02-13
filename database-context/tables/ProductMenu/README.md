# Table: ProductMenu

**OutSystems Entity**: ProductMenu  
**Database Table**: [dbo].[ProductMenu]  
**Purpose**: Product menu items catalog - links products to their classification hierarchy  
**Last Updated**: 2026-02-10  

---

## Overview

ProductMenu stores the master list of menu products. Each row represents a single product with its classification hierarchy (FamilyGroup → Class → Department). Used to get product Code (ProductId) and Name for detail reports.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key, auto-increment |
| `ConceptId` | Long Integer | Foreign key to Concept |
| `ProductId` | Long Integer | Product code (displayed as "Code" in reports) |
| `Name` | Text | Product display name |

### Classification Hierarchy

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `FamilyGroup` | Text | Top-level product family group |
| `Class` | Text | Product class |
| `Department` | Text | Product department |
| `ClassDepartment` | Text | Combined class + department |
| `SubClassDepartment` | Text | Sub-class within department |
| `SubFamilyGroup` | Text | Sub-family within family group |

### Metadata Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `IsChanged` | Boolean | Change tracking flag |
| `LastUpdatedAt` | Date Time | Last update timestamp |

---

## Relationships

### Tables That Reference This Table
- **ProductSalesByOperation** - Links via ProductMenuId
  - Join: `ProductSalesByOperation.ProductMenuId = ProductMenu.Id`
- **SalesFact** - Links via ProductMenuId
  - Join: `SalesFact.ProductMenuId = ProductMenu.Id`

---

## Common Query Patterns

### Get Product Details for Product Mix
```sql
SELECT
    pm.ProductId AS Code,
    pm.Name
FROM {ProductMenu} pm
WHERE pm.Id = @ProductMenuId
```

### Join to ProductSalesByOperation
```sql
SELECT
    pm.ProductId AS Code,
    pm.Name,
    pso.SalesGrossAmt AS Sold,
    pso.TotalGrossAmt AS Total
FROM {ProductSalesByOperation} pso
INNER JOIN {ProductMenu} pm ON pso.ProductMenuId = pm.Id
WHERE pso.SiteId = @SiteId
  AND pso.CalendarDate = @Date
```

---

## Notes for OutSystems
- **ProductId** = The numeric product code shown to users (not the PK)
- **Name** = Product display name (e.g., "Big Mac", "McChicken")
- **Classification** = FamilyGroup > Class > Department hierarchy for grouping/filtering
- **Read Only** = Expose Read Only = Yes (reference data)
