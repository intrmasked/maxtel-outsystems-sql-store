# Table: SWCPosTerminal

**OutSystems Entity**: SWCPosTerminal
**Database Table**: [dbo].[SWCPosTerminal]
**Purpose**: Stores POS terminal session data including opening/closing GT (Grand Total) values
**Last Updated**: 2025-11-28

---

## Overview

SWCPosTerminal records individual POS terminal sessions, tracking grand totals (GT), sales amounts, and session timing. Used for reconciliation and terminal activity tracking.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key, auto-increment |
| `OperatingPeriodId` | Long Integer | FK to operating period |
| `SitePosTerminalId` | Long Integer | Site-specific POS terminal ID |
| `PosId` | Long Integer | POS terminal identifier |
| `OperatingPeriodSalesLogId` | Long Integer | Sales log reference |
| `AlertsJson` | Text | JSON alerts data |
| `InitialGT` | Decimal | Opening Grand Total |
| `FinalGT` | Decimal | Closing Grand Total |
| `NetAmount` | Decimal | Net sales amount |
| `TaxAmount` | Decimal | Tax amount |
| `RoundingSum` | Decimal | Rounding total |
| `OpendDateTime` | Date Time | Session open timestamp |
| `ClosedDateTime` | Date Time | Session close timestamp |
| `IsFromSWC` | Boolean | Data from SWC system flag |
| `Pod` | Text | Point of Delivery type |
| `HasWarnings` | Boolean | Session has warnings |
| `HasErrors` | Boolean | Session has errors |

---

## Relationships

### Tables That Reference This Table
- **SalesFact** - Sales link via PosId
  - Join: `SWCPosTerminal.PosId = SalesFact.PosId`

---

## Common Query Patterns

### Get Terminal GT Values
```sql
SELECT
    PosId,
    Pod,
    InitialGT,
    FinalGT,
    (FinalGT - InitialGT) as GTDifference,
    NetAmount,
    TaxAmount
FROM {SWCPosTerminal}
WHERE OperatingPeriodId = @PeriodId
```

---

## Notes for OutSystems
- InitialGT = Opening grand total for the session
- FinalGT = Closing grand total for the session
- Pod field identifies terminal type (use with GetPodFullName server action)
- GT difference should match sales activity
- Filter by OperatingPeriodId for specific periods
- PosId links to other tables for detailed transaction data
