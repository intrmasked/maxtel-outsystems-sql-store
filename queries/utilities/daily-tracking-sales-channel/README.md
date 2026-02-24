# Query: Daily Tracking Report - Sales Channels

**Location**: `queries/reports/daily-tracking-report/query.sql`
**Category**: Reports
**Created**: 2026-02-24
**Status**: In Testing

---

## Purpose

Returns **3 Sales Channel rows** for a selected business date and site, to populate the `SalesChannels` list in the `DailyTrackingReport` structure:

| Row | Channel | Source |
|-----|---------|--------|
| 1 | MOP | `SWCPeriodTender` filtered by `TenderType.IsMobileEFTPos = 1` |
| 2 | Delivery | `SWCPeriodTender` filtered by `TenderType.IsDelivery = 1` |
| 3 | McCafe | `SalesFact` → `ProductMenu` → `BO_MenuItem` where `IsMcCafe = 1` |

---

## Parameters (OutSystems)

| Parameter | Type | Expand Inline | Description |
|-----------|------|---------------|-------------|
| `SiteId` | LongInteger | No | Site to query |
| `Date` | Date | No | Business date (BusDate for MOP/Delivery, CalendarDate for McCafe) |

---

## Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `SortOrder` | Integer | Row ordering (1=MOP, 2=Delivery, 3=McCafe) |
| `Channel` | Text | Channel name: 'MOP', 'Delivery', 'McCafe' |
| `NetAmount` | Decimal | Net sales amount for the channel |
| `GuestCount` | Decimal | Transaction/guest count |
| `AverageCheck` | Decimal | NetAmount / GuestCount (0 if no guests) |

---

## Data Sources

### MOP & Delivery (SWCPeriodTender)
- **Table**: `SWCPeriodTender` joined to `TenderType`
- **Date join**: Via `SWCPeriod.BusDate` (business date)
- **MOP filter**: `TenderType.IsMobileEFTPos = 1`
- **Delivery filter**: `TenderType.IsDelivery = 1` (includes MOP, DoorDash, UberEats, DeliverEasy)

### McCafe (SalesFact)
- **Table**: `SalesFact` → `ProductMenu` → `BO_MenuItem`
- **Join**: `ProductMenu.ProductId = BO_MenuItem.MIN`
- **Filter**: `BO_MenuItem.IsMcCafe = 1`
- **Date**: `SalesFact.CalendarDate` (calendar date)
- **Dimension filters**: All unused dims nulled out to prevent double-counting

---

## Key Design Decisions

1. **MOP vs Delivery**: MOP is a subset of Delivery (MOP has `IsDelivery = 1` AND `IsMobileEFTPos = 1`). They are separate rows — MOP shows mobile-only, Delivery shows all delivery channels combined.
2. **Date field**: MOP/Delivery use `SWCPeriod.BusDate` (business date). McCafe uses `SalesFact.CalendarDate`. Both should match for same-day queries.
3. **McCafe via SalesFact**: Uses `DatePeriodDimensionId = 15` + `ProductSaleTypeId = 1` + all unused dims nulled — mandatory to avoid double-counting.
4. **CountedAmount for MOP/Delivery**: Uses `SWCPeriodTender.CountedAmount` (consistent with Operating Periods screen).

---

## OutSystems Integration

### Output Structure (JSON)
```json
[
  { "Name": "SortOrder", "Type": "Integer" },
  { "Name": "Channel", "Type": "Text" },
  { "Name": "NetAmount", "Type": "Decimal" },
  { "Name": "GuestCount", "Type": "Decimal" },
  { "Name": "AverageCheck", "Type": "Decimal" }
]
```

### Parameters Setup
| Name | Data Type | Expand Inline |
|------|-----------|---------------|
| SiteId | Long Integer | No |
| Date | Date | No |

---

## Index Recommendations

**Status**: Recommended (Pending DBA review)

1. **IX_SWCPeriodTender_OperatingPeriodId_TenderTypeId** (OperatingPeriodId, TenderTypeId)
   - Impact: High
   - Reason: JOIN + WHERE filter on both columns
   - Status: Recommended

2. **IX_SalesFact_SiteId_CalendarDate_ProductMenuId** (SiteId, CalendarDate, ProductMenuId)
   - Impact: High
   - Reason: McCafe filter starts with SiteId + CalendarDate
   - Status: Recommended

3. **IX_ProductMenu_ProductId** (ProductId)
   - Impact: Medium
   - Reason: JOIN to BO_MenuItem on ProductId
   - Status: Recommended
