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

### Get Sales for a Date and Site
```sql
SELECT
    PosId,
    Pod,
    TenderTypeId,
    SUM(NetAmount) as TotalNet,
    SUM(TaxAmount) as TotalTax
FROM [dbo].[SalesFact]
WHERE CalendarDate = @Date
    AND SiteId = @SiteId
GROUP BY PosId, Pod, TenderTypeId
```

---

## Notes for OutSystems
- Use CalendarDate for date filtering
- TaxAmount contains GST
- NetAmount is pre-tax amount
- Pod field links to POS terminal type
