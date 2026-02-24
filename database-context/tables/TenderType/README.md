# Table: TenderType

**OutSystems Entity**: TenderType
**Database Table**: [dbo].[TenderType]
**Purpose**: Defines payment tender types (Cash, Eftpos, Gift Cards, Delivery, etc.) with categorization and flags
**Last Updated**: 2026-02-24

---

## Overview

TenderType is a reference table that categorizes different payment methods used in transactions. Contains flags like `IsCash`, `IsDelivery`, `IsMobileEFTPos` and other categorization fields for filtering and grouping tenders in reports.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key (OutSystems internal) |
| `ConceptId` | Long Integer | Concept/brand identifier |
| `TenderTypeId` | Long Integer | Tender type identifier (legacy numeric ID) |
| `LegacyId` | Long Integer | Legacy system identifier |
| `Name` | Text | Tender type name (e.g., 'Cash', 'Eftpos', 'MOP', 'Doordash') |
| `Category` | Text | Tender category (e.g., 'TENDER_GIFT_COUPON') |
| `Order` | Integer | Display order for sorting |

### Flag Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `IsCash` | Boolean | True if tender is cash |
| `IsPhysicalTender` | Boolean | True if physical tender (cash/card present) |
| `IsMobileEFTPos` | Boolean | True if mobile EFTPos (e.g., MOP - Mobile Order & Pay) |
| `IsIncludedInSWCTotals` | Boolean | True if included in SWC totals |
| `IsCashEquivilent` | Boolean | True if cash equivalent tender |
| `IsHoldingCash` | Boolean | True if tender holds cash (e.g., float/safe) |
| `IsDelivery` | Boolean | True if delivery tender (MOP, DoorDash, UberEats, DeliverEasy) |

---

## Key Flag Filters

### Cash Tenders
- Filter: `TenderType.IsCash = 1`
- Used for: Cash refund calculations

### Delivery Tenders
- Filter: `TenderType.IsDelivery = 1`
- Includes: MOP, DoorDash, UberEats, DeliverEasy
- Used for: SalesChannels delivery row in tracking reports

### MOP (Mobile Order & Pay)
- Filter: `TenderType.IsMobileEFTPos = 1` OR `TenderType.TenderTypeId = 16`
- Used for: SalesChannels MOP row in tracking reports

### Eftpos Group Tenders
- Filter: `TenderType.TenderTypeId IN (10, 13, 16, 19, 21)`
- Includes: Eftpos, Doordash, MOP, Ubereats, Delivereasy
- Used for: Eftpos refund calculations

### Gift Card/Coupon Tenders
- Filter: `TenderType.Category = 'TENDER_GIFT_COUPON'`
- Used for: Gift card sold calculations

---

## Relationships

### Tables That Reference This Table
- **SWCCashDrawerTender** - Tender details by type
  - Join: `SWCCashDrawerTender.TenderTypeId = TenderType.Id`

---

## Common Query Patterns

### Filter by Cash
```sql
SELECT *
FROM {SWCCashDrawerTender} cdt
INNER JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
WHERE tt.IsCash = 1
```

### Filter by Delivery Tenders
```sql
SELECT *
FROM {SWCCashDrawerTender} cdt
INNER JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
WHERE tt.IsDelivery = 1
```

### Filter by MOP
```sql
SELECT *
FROM {SWCCashDrawerTender} cdt
INNER JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
WHERE tt.TenderTypeId = 16  -- MOP
```

### Filter by Eftpos Group
```sql
SELECT *
FROM {SWCCashDrawerTender} cdt
INNER JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
WHERE tt.TenderTypeId IN (10, 13, 16, 19, 21)
```

### Filter by Category
```sql
SELECT *
FROM {SWCCashDrawerTender} cdt
INNER JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
WHERE tt.Category = 'TENDER_GIFT_COUPON'
```

---

## Notes for OutSystems

- **IsDelivery** = True for MOP, DoorDash, UberEats, DeliverEasy — use for Delivery SalesChannel row
- **IsMobileEFTPos** = True for MOP — cross-check with TenderTypeId = 16
- **IsIncludedInSWCTotals** = True if tender is included in SWC system totals
- **IsCashEquivilent** = True for tenders treated as cash equivalent
- **IsHoldingCash** = True for cash-holding tenders (float, safe drops)
- **IsCash** flag is the preferred way to identify cash tenders
- **TenderTypeId IN (10, 13, 16, 19, 21)** identifies Eftpos group tenders
- **Category** field used for gift card/coupon filtering
- Name field can be used but boolean flags and TenderTypeId are more reliable

---

## Known TenderTypeId Values

| TenderTypeId | Name | IsCash | IsDelivery | IsMobileEFTPos | Notes |
|--------------|------|--------|------------|----------------|-------|
| 10 | Eftpos | False | False | False | Electronic payment |
| 13 | Doordash | False | True | False | Delivery service |
| 16 | MOP | False | True | True | Mobile Order & Pay |
| 19 | Ubereats | False | True | False | Delivery service |
| 21 | Delivereasy | False | True | False | Delivery service |

**Note**: Cash tenders should use `IsCash = 1` flag rather than specific IDs. Delivery tenders should use `IsDelivery = 1`.
