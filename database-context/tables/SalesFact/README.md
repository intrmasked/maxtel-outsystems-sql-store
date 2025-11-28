# Table: SalesFact

**OutSystems Entity**: SalesFact
**Database Table**: [dbo].[SalesFact]
**Purpose**: Stores sales transaction data including tenders, amounts, and tax information
**Last Updated**: 2025-11-28

---

## Overview

The SalesFact table is the main fact table for sales transactions in the MaxTel system. It records all sales activities including tender types, amounts, taxes, and relationships to POS terminals, cash drawers, and operating periods.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key, auto-increment |
| `SiteId` | Long Integer | Foreign key to Site |
| `SalesFactTypeId` | Long Integer | Type of sales fact record |
| `DatePeriodDimensionId` | Long Integer | Date dimension for reporting |
| `CalendarDate` | Date | Transaction calendar date |
| `PosId` | Long Integer | POS terminal ID |
| `Pod` | Text | Point of Delivery identifier |
| `SWCCashDrawerId` | Long Integer | FK to SWCCashDrawer |
| `CashDrawerId` | Long Integer | Alternative cash drawer ID |
| `TenderTypeId` | Long Integer | Type of tender (Cash, Eftpos, etc.) |
| `Quantity` | Decimal | Transaction quantity |
| `NetAmount` | Decimal | Net sales amount (excluding tax) |
| `TaxAmount` | Decimal | GST/Tax amount |
| `NetBeforeDiscount` | Decimal | Amount before discounts applied |
| `TaxBeforeDiscount` | Decimal | Tax before discounts |
| `RoundingAmount` | Decimal | Rounding adjustment |
| `TransactionCount` | Integer | Number of transactions |
| `DateTime` | Date Time | Transaction timestamp |
| `ProductMenuId` | Long Integer | Product menu reference |
| `OperationId` | Long Integer | Operation reference |
| `OperationKindId` | Long Integer | Kind of operation |
| `ProductSaleTypeId` | Long Integer | Product sale type |
| `SaleTypeId` | Long Integer | Sale type |
| `SourceFileId` | Long Integer | Source file reference |
| `SWCPeriodId` | Long Integer | Operating period reference |

---

## Relationships

### Tables This Table References
- **SWCCashDrawer** - Links to cash drawer
  - Join: `SalesFact.SWCCashDrawerId = SWCCashDrawer.Id`
- **SWCPosTerminal** - Links via PosId
  - Join: `SalesFact.PosId = SWCPosTerminal.PosId`

---

## Common Query Patterns

### Get Sales for a Date and Site (via Operating Period)
```sql
SELECT
    SWCPeriodId,
    SUM(NetAmount) as TotalNet,
    SUM(TaxAmount) as TotalTax
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND PosId <> ''
    AND Pod <> ''
GROUP BY SWCPeriodId
```

### Join to SWCPeriod
```sql
SELECT
    p.SiteId,
    p.BusDate,
    sf.NetAmount,
    sf.TaxAmount
FROM {SWCPeriod} p
INNER JOIN {SalesFact} sf
    ON p.Id = sf.SWCPeriodId
WHERE p.SiteId = @SiteId
    AND p.BusDate = @Date
    AND sf.DatePeriodDimensionId = 15
    AND sf.PosId <> ''
    AND sf.Pod <> ''
```

---

## Mandatory Filter Rules (ALWAYS APPLY)

**🚨 CRITICAL: When querying SalesFact, ALWAYS filter unused dimension IDs to NULL:**

```sql
-- Standard filters (ALWAYS required)
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND PosId <> ''
    AND Pod <> ''
    AND PosId IS NOT NULL

-- Dimension filters (set to NULL if NOT using that dimension)
    AND ProductMenuId IS NULL        -- ALWAYS NULL unless filtering by product menu
    AND TenderTypeId IS NULL         -- ALWAYS NULL unless filtering by tender type
    AND OperationId IS NULL          -- ALWAYS NULL unless filtering by operation
    AND OperationKindId IS NULL      -- ALWAYS NULL unless filtering by operation kind
    AND SWCCashDrawerId IS NULL      -- ALWAYS NULL unless filtering by cash drawer
    AND SaleTypeId IS NULL           -- ALWAYS NULL unless filtering by sale type

-- Product type filters (use when needed)
    AND ProductSaleTypeId = 1        -- Use 1 for product sales, 2 for non-product sales
    AND ProductSaleTypeId IS NOT NULL
```

**Why these filters are mandatory:**
- SalesFact is a large fact table with multiple dimensions
- Setting unused dimension IDs to NULL ensures accurate aggregation
- Prevents double-counting or incorrect sums
- If you're NOT using a specific dimension (MenuId, TenderTypeId, etc.), it MUST be NULL

---

## Notes for OutSystems
- **Join via SWCPeriodId** - Links to SWCPeriod.Id (OperatingPeriodId)
- **DatePeriodDimensionId = 15** - Standard dimension filter
- **Filter out empty strings** - PosId <> '' AND Pod <> ''
- Use CalendarDate for date filtering
- TaxAmount contains GST
- NetAmount is pre-tax amount
- Large table - always use indexed filters (SiteId, CalendarDate, DatePeriodDimensionId)
- **ALWAYS set unused dimension IDs to NULL** - See Mandatory Filter Rules above
