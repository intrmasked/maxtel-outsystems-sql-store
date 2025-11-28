# Query: Product Sales By Drawer

**Category**: Reports
**Created**: 2025-11-28
**Status**: In Progress - Pending equation confirmations
**SQL Server**: 2014+ compatible

---

## Purpose

Cash drawer reconciliation report that shows:
- Grand Total (GT) opening and closing values per POS terminal
- Cash and Eftpos refunds by drawer
- Gift Card/Coupon sales
- GST/Tax amounts
- Product sales breakdown (pending equation confirmation)

Filtered by site and date for daily reconciliation.

---

## Output Columns

| Column | Source | Description |
|--------|--------|-------------|
| POS | `SWCCashDrawer.PosId` | POS terminal ID |
| Type | `SWCPosTerminal.Pod` | Terminal type (pass to GetPodFullName) |
| Close | `SWCCashDrawer.FinalGT` | Closing Grand Total |
| Open | `SWCCashDrawer.InitialGT` | Opening Grand Total |
| Difference | Calculated | FinalGT - InitialGT |
| Overring | Fixed | Always 0 |
| CashRefund | `SWCCashDrawerTender` | Refunds for TenderTypeId = 0 |
| EftposRefund | `SWCCashDrawerTender` | Refunds for TenderTypeId IN (10,13,16,19,21) |
| GCSold | `SWCCashDrawerTender` | Gift Card/Coupon sales (TENDER_GIFT_COUPON) |
| GrossSales | TODO | Pending equation confirmation |
| GST | `SalesFact.TaxAmount` | Total tax amount |
| NetSales | TODO | Pending equation confirmation |
| NonProdSales | TODO | Field doesn't exist yet (0 for now) |
| ProductSales | Calculated | NetSales - NonProdSales |

---

## Parameters

- **@SiteId**: Site identifier (BIGINT)
- **@Date**: Transaction date (DATE format: 'YYYY-MM-DD')

**To change parameters**: Edit the DECLARE statements at the top of query.sql

---

## Tables Used

- `SWCPeriod` - Operating period (primary filter by SiteId and BusDate)
- `SWCCashDrawer` - Main drawer session data (GT values)
- `SWCPosTerminal` - POS terminal info (Pod/Type)
- `SWCCashDrawerTender` - Tender-specific refunds and amounts
- `TenderType` - Tender categories (for TENDER_GIFT_COUPON)
- `SalesFact` - Tax/GST amounts (joins via SWCPeriodId)

---

## TenderType Mapping

| Tender | TenderTypeId(s) | Used For |
|--------|----------------|----------|
| Cash | 0 | CashRefund |
| Eftpos Group | 10, 13, 16, 19, 21 | EftposRefund |
| Gift Card/Coupon | Category = 'TENDER_GIFT_COUPON' | GCSold |

**Note**: Eftpos group includes: Eftpos, Doordash, MOP, Ubereats, Delivereasy

---

## Sales Calculations

### Gross Sales Formula:
```
GrossSales = Difference - Overring - CashRefund - EftposRefund - OtherReceipt - GCSold
```

Where:
- **Difference** = Close (FinalGT) - Open (InitialGT)
- **Overring** = Always 0
- **CashRefund** = Refunds for TenderTypeId = 0
- **EftposRefund** = Refunds for TenderTypeIds IN (10,13,16,19,21)
- **OtherReceipt** = 0 (removed as per requirements)
- **GCSold** = Gift Card/Coupon sales

### Net Sales:
```
NetSales = GrossSales - GST
```

### Non-Product Sales:
```
NonProdSales = SUM(NetAmount) from SalesFact WHERE ProductSaleTypeId = 2
```

### Product Sales:
```
ProductSales = NetSales - NonProdSales
```

---

## Implementation Status

✅ **Complete**:
- GrossSales equation implemented
- NetSales equation implemented
- NonProdSales from SalesFact (ProductSaleTypeId = 2)
- ProductSales calculation
- TenderType.Category verified
- SiteId filter via SWCPeriod
- Date filter via SWCPeriod.BusDate
- SalesFact joins via SWCPeriodId

⏳ **Pending**:
- Testing with production data
- GetPodFullName server action validation
- DBA review of index recommendations

---

## Index Recommendations

**Status**: Recommended (Pending DBA review)

1. **IX_SWCPeriod_SiteId_BusDate** (SiteId, BusDate)
   - Impact: **High** - Primary query filter
   - Reason: WHERE clause filtering

2. **IX_SWCCashDrawer_OperatingPeriodId** (OperatingPeriodId)
   - Impact: **High** - JOIN performance
   - Reason: Main JOIN to SWCPeriod

3. **IX_SWCPosTerminal_OperatingPeriodId_PosId** (OperatingPeriodId, PosId)
   - Impact: Medium - JOIN and grouping

4. **IX_SalesFact_SiteId_CalendarDate_DatePeriodDimensionId** (SiteId, CalendarDate, DatePeriodDimensionId, SWCPeriodId)
   - Impact: **Critical** - Large fact table with multiple filters
   - Reason: Subquery filtering on large table

5. **IX_SWCCashDrawerTender_OperatingPeriodCashDrawerId** (OperatingPeriodCashDrawerId)
   - Impact: Medium - Tender JOIN performance

---

## How to Use in OutSystems

1. Copy query to Advanced SQL Block
2. Update @SiteId and @Date parameter values (or pass from OutSystems inputs)
3. For the "Type" column, pass the Pod value to **GetPodFullName** server action
4. Review output structure with pending equations before finalizing

---

## Next Steps

- Confirm GrossSales and NetSales equations
- Test TenderType.Category field availability
- Verify date filtering approach
- Add NonProdSales logic when field becomes available
- Test with real data
