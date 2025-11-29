# Table: SalesFact

**OutSystems Entity**: SalesFact
**Database Table**: [dbo].[SalesFact]
**Purpose**: Stores sales transaction data including tenders, amounts, and tax information
**Last Updated**: 2025-11-29

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
| `TransactionCount` | Integer | Number of transactions (guest count) |
| `DateTime` | Date Time | Transaction timestamp (UTC timezone) |
| `ProductMenuId` | Long Integer | Product menu reference |
| `OperationId` | Long Integer | Operation reference |
| `OperationKindId` | Long Integer | Kind of operation |
| `ProductSaleTypeId` | Long Integer | Product sale type (1 = product sales, 2 = non-product sales) |
| `SaleTypeId` | Long Integer | Sale type |
| `SourceFileId` | Long Integer | Source file reference |
| `SWCPeriodId` | Long Integer | Operating period reference |
| `DatePeriodDimensionId` | Long Integer | Date period dimension (15 = 15-min intervals, 1440 = daily) |

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

## Timezone and DateTime Handling

**🚨 CRITICAL: Database stores DateTime in UTC, reports need NZ timezone**

### UTC to NZ Timezone Conversion Pattern:
```sql
-- Convert UTC DateTime to NZ timezone
CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')

-- Extract hour in NZ timezone (for hourly reports)
DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time'))

-- Extract date in NZ timezone
CAST(CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time') AS DATE)
```

**Why timezone conversion matters:**
- Database stores all DateTime values in UTC
- Business operates in NZ timezone (NZDT = UTC+13, NZST = UTC+12)
- Without conversion, hourly reports would show UTC hours, not NZ hours
- AT TIME ZONE automatically handles daylight saving transitions

**Example - Hourly Sales:**
```sql
-- Get sales grouped by NZ hour
SELECT
    DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS Hour,
    SUM(NetAmount) AS Sales
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    -- ... other mandatory filters
GROUP BY DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time'))
ORDER BY Hour
```

---

## DatePeriodDimensionId Values

| Value | Interval | Use Case |
|-------|----------|----------|
| 15 | 15-minute intervals | Hourly reports, detailed time analysis |
| 1440 | Daily (24 hours × 60 mins) | Daily aggregation reports |

**Standard Usage**: Use `DatePeriodDimensionId = 15` for most queries to get granular time data

---

## Notes for OutSystems
- **Join via SWCPeriodId** - Links to SWCPeriod.Id (OperatingPeriodId)
- **DatePeriodDimensionId = 15** - Standard dimension filter for 15-min intervals
- **Filter out empty strings** - PosId <> '' AND Pod <> ''
- **CalendarDate** - Use for date filtering (stored in UTC, but represents calendar day)
- **DateTime** - Transaction timestamp (UTC), convert to NZ for hourly analysis
- **TaxAmount** - Contains GST
- **NetAmount** - Pre-tax sales amount
- **TransactionCount** - Guest count (number of transactions)
- **ProductSaleTypeId** - 1 = product sales, 2 = non-product sales
- **Pod codes** - 2-3 letter codes (e.g., CO, DT, KI, DL) - convert with GetPODFullName
- Large table - always use indexed filters (SiteId, CalendarDate, DatePeriodDimensionId)
- **ALWAYS set unused dimension IDs to NULL** - See Mandatory Filter Rules above
