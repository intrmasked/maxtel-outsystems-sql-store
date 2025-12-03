# Table: TenderType

**OutSystems Entity**: TenderType
**Database Table**: [dbo].[TenderType]
**Purpose**: Defines payment tender types (Cash, Eftpos, Gift Cards, etc.) with categorization and flags
**Last Updated**: 2025-12-03

---

## Overview

TenderType is a reference table that categorizes different payment methods used in transactions. Contains flags like IsCash and categorization fields for filtering and grouping tenders.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key (TenderTypeId) |
| `TenderTypeId` | Long Integer | Tender type identifier |
| `Name` | Text | Tender type name (e.g., 'Cash', 'Eftpos', 'Doordash') |
| `Category` | Text | Tender category (e.g., 'TENDER_GIFT_COUPON') |
| `IsCash` | Boolean | Flag indicating if tender is cash (1 = true, 0 = false) |

---

## Common Tender Types

### Cash Tenders
- Filter: `TenderType.IsCash = 1`
- Used for: Cash refund calculations

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

- **IsCash flag** is the preferred way to identify cash tenders
- **TenderTypeId IN (10, 13, 16, 19, 21)** identifies Eftpos group tenders
- **Category field** used for gift card/coupon filtering
- Name field can be used but IsCash and TenderTypeId are more reliable

---

## Known TenderTypeId Values

| TenderTypeId | Name | Notes |
|--------------|------|-------|
| 10 | Eftpos | Electronic payment |
| 13 | Doordash | Delivery service payment |
| 16 | MOP | Payment type |
| 19 | Ubereats | Delivery service payment |
| 21 | Delivereasy | Delivery service payment |

**Note**: Cash tenders should use `IsCash = 1` flag rather than specific IDs
