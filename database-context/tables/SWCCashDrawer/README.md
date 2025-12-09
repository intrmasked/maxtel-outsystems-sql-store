# Table: SWCCashDrawer

**OutSystems Entity**: SWCCashDrawer
**Database Table**: [dbo].[SWCCashDrawer]
**Purpose**: Main cash drawer session table tracking GT values, reconciliation, and drawer totals
**Last Updated**: 2025-11-28

---

## Overview

SWCCashDrawer is the primary table for cash drawer sessions. Tracks opening/closing grand totals (GT), expected vs counted cash, transfers, and reconciliation status.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key, auto-increment |
| `OperatingPeriodId` | Long Integer | FK to operating period |
| `PosId` | Long Integer | POS terminal ID |
| `OpSessionId` | Long Integer | Operating session ID |
| `CountedAt` | Date Time | When drawer was counted |
| `CountedBy` | Long Integer | User who counted |
| `Notes` | Text | Drawer notes |
| `IsAutoReconciled` | Boolean | Auto-reconciled flag |
| `TotalExpectedCash` | Decimal | Expected total cash |
| `TotalCountedCash` | Decimal | Actual counted cash |
| `CashEquivilentOffset` | Decimal | Cash equivalent offset |
| `TransferOut` | Decimal | Cash transferred out |
| `TransferIn` | Decimal | Cash transferred in |
| `InitialGT` | Decimal | Opening Grand Total |
| `FinalGT` | Decimal | Closing Grand Total |
| `NetAmount` | Decimal | Net sales amount |
| `TaxAmount` | Decimal | Tax amount |
| `RoundingSum` | Decimal | Rounding total |
| `LogInDateTime` | Date Time | Drawer login time |
| `LogOutDateTime` | Date Time | Drawer logout time |
| `OperatorUserId` | Long Integer | Operator user ID |
| `NewPos6FileId` | Long Integer | POS file reference |
| `IsSeemlessLogin` | Boolean | Seamless login flag |
| `IsSeemlessLogout` | Boolean | Seamless logout flag |
| `OperatorSessionId` | Long Integer | Operator session ID |
| `HasError` | Boolean | Error flag |
| `Error` | Text | Error message |
| `PromoAmount` | Decimal | Promotion amount |
| `PromoCount` | Integer | Promotion count |
| `DiscountAmount` | Decimal | Discount amount |
| `DiscountCount` | Integer | Discount count |
| `CrewMealsAmount` | Decimal | Crew meals total |
| `CrewMealsCount` | Integer | Crew meals count |
| `ManagerMealsAmount` | Decimal | Manager meals total |
| `ManagerMealsCount` | Integer | Manager meals count |
| `ReductionBeforeTotal` | Decimal | Reductions before total |
| `ReductionAfterTotal` | Decimal | Reductions after total |
| `ReductionCount` | Integer | Reduction count |
| `NonProductSalesAmount` | Decimal | Non-product sales total |
| `NonProductSalesCount` | Integer | Non-product sales count |
| `GiftCouponSales` | Decimal | Gift coupon sales total |

---

## Relationships

### Tables That Reference This Table
- **SWCCashDrawerTender** - Tender details for this drawer
  - Join: `SWCCashDrawer.Id = SWCCashDrawerTender.OperatingPeriodCashDrawerId`
- **SalesFact** - Sales linked to this drawer
  - Join: `SWCCashDrawer.Id = SalesFact.SWCCashDrawerId`

---

## Common Query Patterns

### Get Cash Drawer GT Summary
```sql
SELECT
    PosId,
    InitialGT,
    FinalGT,
    (FinalGT - InitialGT) as GTDifference,
    TotalExpectedCash,
    TotalCountedCash,
    NetAmount,
    TaxAmount
FROM {SWCCashDrawer}
WHERE OperatingPeriodId = @PeriodId
    AND PosId = @PosId
```

---

## Notes for OutSystems
- InitialGT = Opening grand total for the session
- FinalGT = Closing grand total for the session
- GT Difference = FinalGT - InitialGT
- Contains aggregated drawer-level data
- Link to SWCCashDrawerTender for tender-specific details
- Filter by OperatingPeriodId and/or PosId for session data
