# Table: SWCCashDrawerTender

**OutSystems Entity**: SWCCashDrawerTender
**Database Table**: [dbo].[SWCCashDrawerTender]
**Purpose**: Stores tender-specific cash drawer details including refunds and counted amounts
**Last Updated**: 2025-11-28

---

## Overview

SWCCashDrawerTender tracks individual tender types within a cash drawer session. Records expected vs counted amounts, refunds, and transaction counts for each payment method.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key, auto-increment |
| `OperatingPeriodCashDrawerId` | Long Integer | FK to cash drawer (operating period) |
| `TenderTypeId` | Long Integer | FK to TenderType (Cash, Eftpos, etc.) |
| `InitialFloat` | Decimal | Starting float amount |
| `DrawerAmount` | Decimal | Total drawer amount |
| `CashOutCount` | Integer | Number of cash-out transactions |
| `CashOutAmount` | Decimal | Total cash-out amount |
| `ExpectedAmount` | Decimal | Expected tender amount |
| `CountedAmount` | Decimal | Actual counted amount |
| `RefundAmount` | Decimal | Total refund amount for this tender |
| `RefundCount` | Integer | Number of refund transactions |
| `RoundingAmount` | Decimal | Rounding adjustments |
| `SkimmedAmount` | Decimal | Skimmed/removed cash |
| `IsCounted` | Boolean | Has been counted flag |
| `CashEquivilentOffset` | Decimal | Cash equivalent offset |
| `CashBagId` | Long Integer | Cash bag reference |
| `UpdatedBy` | Long Integer | User who updated |
| `UpdatedAt` | Date Time | Update timestamp |
| `IsFromSeemlessLogout` | Boolean | From seamless logout |
| `SeemlessLogoutExpectedAmount` | Decimal | Seamless logout expected |
| `SeemlessLogoutDrawerTenderId` | Long Integer | Seamless logout tender ref |
| `OriginalExpectedAmount` | Decimal | Original expected amount |
| `TransactionCount` | Integer | Number of transactions |

---

## Relationships

### Tables This Table References
- **SWCCashDrawer** - Parent cash drawer
  - Join: `SWCCashDrawerTender.OperatingPeriodCashDrawerId = SWCCashDrawer.Id`

---

## Common Query Patterns

### Get Refunds by Tender Type
```sql
SELECT
    TenderTypeId,
    SUM(RefundAmount) as TotalRefunds,
    SUM(RefundCount) as RefundCount
FROM {SWCCashDrawerTender}
WHERE OperatingPeriodCashDrawerId = @CashDrawerId
GROUP BY TenderTypeId
```

### Get Net Amount by Tender (GC Sold pattern)
```sql
-- For Gift Card/Coupon tenders
SELECT
    SUM(DrawerAmount) as NetAmount
FROM {SWCCashDrawerTender}
WHERE OperatingPeriodCashDrawerId = @CashDrawerId
    AND TenderTypeId IN (/* Gift Card Tender IDs */)
```

---

## Notes for OutSystems
- RefundAmount and RefundCount track refunds per tender type
- Filter by TenderTypeId for specific payment methods (Cash, Eftpos, Gift Cards, etc.)
- Multiple TenderTypeIds can represent similar payment methods (group as needed)
- Use DrawerAmount, ExpectedAmount, or CountedAmount depending on use case
- Link to parent SWCCashDrawer via OperatingPeriodCashDrawerId
