# Table: SWCPeriod

**OutSystems Entity**: SWCPeriod
**Database Table**: [dbo].[SWCPeriod]
**Purpose**: Operating period tracking with site, date, and aggregated sales data
**Last Updated**: 2025-11-28

---

## Overview

SWCPeriod represents an operating period (typically a business day) for a site. Contains aggregated totals, GT values, and period status. Used as the central link for filtering by SiteId and date.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key (OperatingPeriodId) |
| `SiteId` | Long Integer | FK to Site - for filtering by location |
| `BusDate` | Date | Business date for the period |
| `OpenDateTime` | Date Time | Period open timestamp |
| `CloseDateTime` | Date Time | Period close timestamp |
| `QtrHourNumber` | Integer | Quarter hour number |
| `IsComplete` | Boolean | Period completion status |
| `IsClosed` | Boolean | Period closed flag |
| `TransactionCount` | Integer | Total transaction count |
| `NetAmount` | Decimal | Net sales amount |
| `TaxAmount` | Decimal | Tax amount |
| `RoundingSum` | Decimal | Rounding total |
| `TotalVariance` | Decimal | Total variance |
| `Notes` | Text | Period notes |
| `ClosedAt` | Date Time | When period was closed |
| `ClosedBy` | Long Integer | User who closed period |
| `InitialGT` | Decimal | Opening Grand Total |
| `FinalGT` | Decimal | Closing Grand Total |
| `HasWarnings` | Boolean | Period has warnings |
| `HasErrors` | Boolean | Period has errors |
| `Summary` | Text | Period summary |
| `PreviousOperatingPeriodId` | Long Integer | Link to previous period |
| `SWOFileId` | Long Integer | SWO file reference |
| `SWCFileId` | Long Integer | SWC file reference |
| `ItemsToBeCounted` | Integer | Items to count |
| `ItemsToBeBagged` | Integer | Items to bag |
| `BagsToBeDropped` | Integer | Bags to drop |
| `HasBeenMigrated` | Boolean | Migration flag |
| `Hourly1PMAdjustment` | Decimal | Hourly adjustment |
| `LastUpdatedAt` | Date Time | Last update timestamp |
| `TransCountDailyDelta` | Integer | Transaction count delta |
| `NetAmountDailyDelta` | Decimal | Net amount delta |
| `TaxAmountDailyDelta` | Decimal | Tax amount delta |
| `RoundingSumDailyDelta` | Decimal | Rounding delta |
| `PeriodTotalSalesGross` | Decimal | Gross sales for period |
| `PeriodProductSalesNet` | Decimal | Net product sales for period |
| `ProductSalesBeforeMidnight` | Decimal | Product sales before midnight |
| `ProductSalesAfterMidnight` | Decimal | Product sales after midnight |
| `TotalReductionAmount` | Decimal | Total reductions |
| `TotalReductionOccurrences` | Integer | Reduction count |
| `SecurityPromotionAmount` | Decimal | Security promotion amount |
| `TotalReductionAmtBeforeTotal` | Decimal | Reductions before total |

---

## Relationships

### Tables That Reference This Table
- **SWCCashDrawer** - Cash drawer sessions
  - Join: `SWCCashDrawer.OperatingPeriodId = SWCPeriod.Id`
- **SWCPosTerminal** - POS terminal sessions
  - Join: `SWCPosTerminal.OperatingPeriodId = SWCPeriod.Id`

---

## Common Query Patterns

### Filter by Site and Date
```sql
SELECT
    Id,
    SiteId,
    BusDate,
    InitialGT,
    FinalGT,
    NetAmount,
    TaxAmount
FROM [dbo].[SWCPeriod]
WHERE SiteId = @SiteId
    AND BusDate = @Date
```

### Join to Cash Drawer via Period
```sql
SELECT
    p.SiteId,
    p.BusDate,
    cd.PosId,
    cd.InitialGT,
    cd.FinalGT
FROM [dbo].[SWCPeriod] p
INNER JOIN [dbo].[SWCCashDrawer] cd
    ON p.Id = cd.OperatingPeriodId
WHERE p.SiteId = @SiteId
    AND p.BusDate = @Date
```

---

## Notes for OutSystems
- **Primary filter table** - Use for SiteId and BusDate filtering
- BusDate = Business date (use for @Date parameter)
- Id = OperatingPeriodId referenced by other tables
- Contains aggregated period totals (useful for validation)
- InitialGT/FinalGT at period level (may differ from individual drawer totals)

---

## Index Recommendations

**Recommended indexes:**
- `IX_SWCPeriod_SiteId_BusDate` (SiteId, BusDate) - For date/site filtering
- `IX_SWCPeriod_BusDate` (BusDate) - For date-only queries

**Existing indexes:** Check with DBA team
