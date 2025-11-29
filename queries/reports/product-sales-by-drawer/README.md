# Query: Product Sales By Drawer

**Category**: Reports
**Created**: 2025-11-28
**Status**: In Testing - Optimized
**SQL Server**: 2014+ compatible
**Optimization**: Single SalesFact query (66% reduction in DB hits)

---

## Purpose

Cash drawer reconciliation report that shows:
- Grand Total (GT) opening and closing values per POS terminal
- Cash and Eftpos refunds by drawer
- Gift Card/Coupon sales
- GST/Tax amounts
- Product and non-product sales breakdown
- Total row summing all numeric columns

Filtered by site and date for daily reconciliation.

**Query Structure:**
- Uses CTE (PerPosData) for per-POS calculations
- UNION ALL for Total row at bottom
- Single optimized SalesFact query (not 3 separate queries)

---

## Output Columns

| Column | Source | Description |
|--------|--------|-------------|
| POS | `SWCCashDrawer.PosId` | POS terminal ID (or 'Total' for total row) |
| Type | `SWCPosTerminal.Pod` | Terminal type (pass to GetPodFullName, NULL for total) |
| Close | `SWCCashDrawer.FinalGT` | Closing Grand Total (NULL for total) |
| Open | `SWCCashDrawer.InitialGT` | Opening Grand Total (NULL for total) |
| Difference | Calculated | FinalGT - InitialGT |
| CashRefund | `SWCCashDrawerTender` | Refunds for TenderTypeId = 0 |
| EftposRefund | `SWCCashDrawerTender` | Refunds for TenderTypeId IN (10,13,16,19,21) |
| GCSold | `SWCCashDrawerTender` | Gift Card/Coupon CountedAmount (TENDER_GIFT_COUPON) |
| GrossSales | Calculated | Difference - CashRefund - EftposRefund - GCSold |
| GST | `SalesFact.TaxAmount` | Total tax amount (all ProductSaleTypeId) |
| NetSales | Calculated | GrossSales - GST |
| NonProdSales | `SalesFact.NetAmount` | WHERE ProductSaleTypeId = 2 |
| ProdSales | `SalesFact.NetAmount` | WHERE ProductSaleTypeId = 1 |

**Note:** Total row shows sum of all numeric columns (Difference through ProdSales).

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
GrossSales = Difference - CashRefund - EftposRefund - GCSold
```

Where:
- **Difference** = Close (FinalGT) - Open (InitialGT)
- **CashRefund** = Refunds for TenderTypeId = 0
- **EftposRefund** = Refunds for TenderTypeIds IN (10,13,16,19,21)
- **GCSold** = Gift Card/Coupon CountedAmount (Category = 'TENDER_GIFT_COUPON')

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
ProdSales = SUM(NetAmount) from SalesFact WHERE ProductSaleTypeId = 1
```

---

## Implementation Status

✅ **Complete**:
- GrossSales equation implemented
- NetSales equation implemented
- NonProdSales from SalesFact (ProductSaleTypeId = 2)
- ProdSales from SalesFact (ProductSaleTypeId = 1)
- TenderType.Category verified
- SiteId filter via SWCPeriod
- Date filter via SWCPeriod.BusDate
- SalesFact optimized to single query (3 → 1 query)
- Total row added at bottom
- Query matches OutSystems structure (13 columns)

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

## Performance Optimization

**Database Hit Reduction:**
- **Before**: 3 separate SalesFact subqueries (sf, sfProd, sfNonProd)
- **After**: 1 single SalesFact query with CASE statements
- **Impact**: 66% reduction in SalesFact table access

**Query Pattern:**
```sql
-- Single optimized SalesFact query
LEFT JOIN (
    SELECT
        PosId, Pod,
        SUM(TaxAmount) AS TotalTax,
        SUM(CASE WHEN ProductSaleTypeId = 1 THEN NetAmount ELSE 0 END) AS ProdSales,
        SUM(CASE WHEN ProductSaleTypeId = 2 THEN NetAmount ELSE 0 END) AS NonProdSales
    FROM {SalesFact}
    WHERE [filters]
    GROUP BY PosId, Pod
) sf ON cd.PosId = sf.PosId AND pt.Pod = sf.Pod
```

---

## Next Steps

- Test with production data
- Validate Total row calculations
- GetPodFullName server action integration
- DBA review and implement index recommendations
