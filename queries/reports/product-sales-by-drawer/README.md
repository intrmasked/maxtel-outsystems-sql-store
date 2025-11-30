# Query: Product Sales By Drawer

**Category**: Reports
**Created**: 2025-11-28
**Updated**: 2025-11-30
**Status**: Migrated to OutSystems Aggregates
**Implementation**: OutSystems Aggregates (not Advanced SQL)

---

## ⚠️ IMPORTANT: Implementation Change

**This query is now implemented using OutSystems Aggregates instead of Advanced SQL.**

The SQL query files in this folder are **archived for reference only**. The active implementation is in OutSystems using the visual query builder (Aggregates).

**Reason for change**:
- Simpler data structure (straightforward joins and aggregations)
- No complex CTEs, window functions, or timezone conversions needed
- Easier maintenance with visual query builder
- Type safety and validation built into OutSystems
- Direct integration with GetPodFullName server action

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

---

## Updated Requirements (2025-11-30)

### Output Columns

| Column | Source | Description |
|--------|--------|-------------|
| POS | `SWCCashDrawer.POSId` | POS terminal ID |
| Type | `SalesFact.Pod` or `SWCPosTerminal.Pod` | Pass to GetPodFullName server action |
| Close | `SWCCashDrawer.GTFinal` | Closing Grand Total |
| Open | `SWCCashDrawer.GTInitial` | Opening Grand Total |
| Difference | Calculated | Close - Open |
| ~~Overring~~ | Removed | Always 0, not needed |
| Cash Refund | `SWCCashDrawerTender.RefundAmount` | TenderType = Cash |
| Eftpos Refund | `SWCCashDrawerTender.RefundAmount` | TenderType = Eftpos, Doordash, MOP, Ubereats, Delivereasy |
| ~~Other Receipt~~ | Removed | Not needed |
| GC Sold | `SWCCashDrawerTender.NetAmount` | TenderType.Category = TENDER_GIFT_COUPON |
| Gross Sales | Calculated | See equation below |
| GST | `SWCCashDrawer.TaxAmount` | Total tax amount |
| Net Sales | Calculated | See equation below |
| Non Prod Sales | Placeholder | Field doesn't exist yet, leave blank |
| Product Sales | Calculated | Net Sales - Non Prod Sales |

### Total Row
- Sum all numeric columns (Difference through Product Sales)
- POS = NULL or 'Total'
- Type = 'Total'
- Close/Open = NULL

---

## Implementation in OutSystems (Aggregates)

### Main Aggregate Structure

**Entities to Join**:
1. `SWCCashDrawer` (main entity)
2. `SWCCashDrawerTender` (for refunds and GC sold)
3. `SWCPosTerminal` (for Pod/Type) OR use `SalesFact.Pod`
4. `TenderType` (for Category filtering)

**Group By**:
- POSId
- Pod

**Aggregations**:
- `SUM(RefundAmount)` WHERE TenderType = Cash → Cash Refund
- `SUM(RefundAmount)` WHERE TenderType IN (Eftpos, Doordash, MOP, Ubereats, Delivereasy) → Eftpos Refund
- `SUM(NetAmount)` WHERE TenderType.Category = 'TENDER_GIFT_COUPON' → GC Sold
- `GTFinal`, `GTInitial`, `TaxAmount` from SWCCashDrawer

**Calculated Attributes** (in Aggregate or Server Action):
- `Difference = Close - Open`
- `GrossSales = Difference - CashRefund - EftposRefund - GCSold`
- `NetSales = GrossSales - GST`
- `ProductSales = NetSales - NonProdSales` (NonProdSales currently 0)

**Total Row**:
- Create separate aggregate or use `List_Sum()` in server action to calculate totals
- Add Total row to output list

**GetPodFullName Integration**:
- Loop through results in Server Action
- Call `GetPodFullName(Pod)` for each row
- Map result to Type column

---

## TenderType Mapping

| Tender | Identifier | Used For |
|--------|-----------|----------|
| Cash | TenderType = 'Cash' | Cash Refund |
| Eftpos Group | TenderType IN ('Eftpos', 'Doordash', 'MOP', 'Ubereats', 'Delivereasy') | Eftpos Refund |
| Gift Card/Coupon | TenderType.Category = 'TENDER_GIFT_COUPON' | GC Sold |

---

## Sales Calculations

### Gross Sales Formula:
```
GrossSales = Difference - CashRefund - EftposRefund - GCSold
```

Where:
- **Difference** = Close (GTFinal) - Open (GTInitial)
- **CashRefund** = RefundAmount for TenderType = Cash
- **EftposRefund** = RefundAmount for Eftpos group
- **GCSold** = NetAmount where Category = TENDER_GIFT_COUPON

### Net Sales:
```
NetSales = GrossSales - GST
```

### Product Sales:
```
ProductSales = NetSales - NonProdSales
```
*(NonProdSales currently blank/0 until field exists)*

---

## Parameters

- **SiteId**: Site identifier (Long Integer)
- **Date**: Transaction date (Date)

Pass these as Input Parameters to the Server Action containing the Aggregate.

---

## Archived SQL Files

The following SQL files are kept for reference but are **NOT USED** in production:

- `query.sql` - Original SQL implementation
- `tests/` - SQL test queries

**Do not use these files** - they represent an older implementation approach.

---

## Implementation Checklist

- [x] Requirements updated (2025-11-30)
- [ ] OutSystems Aggregate created
  - [ ] Join SWCCashDrawer + SWCCashDrawerTender + SWCPosTerminal
  - [ ] Filter by SiteId and Date
  - [ ] Group by POSId, Pod
  - [ ] Aggregate RefundAmount for Cash and Eftpos
  - [ ] Aggregate NetAmount for GC Sold
- [ ] Server Action logic
  - [ ] Calculate Difference, GrossSales, NetSales, ProductSales
  - [ ] Loop through results
  - [ ] Call GetPodFullName for each Pod
  - [ ] Add Total row (sum of all numeric columns)
- [ ] Testing
  - [ ] Validate calculations match expected values
  - [ ] Verify Total row sums correctly
  - [ ] Test with production data

---

## Next Steps

1. Create OutSystems Aggregate following structure above
2. Build Server Action to:
   - Execute Aggregate
   - Calculate derived fields (Difference, GrossSales, NetSales, ProductSales)
   - Call GetPodFullName for Type column
   - Generate Total row
3. Test with production data
4. Validate against business requirements
5. Archive SQL query files once Aggregate implementation is confirmed working

---

## Why Aggregates Instead of SQL?

**Advantages**:
- ✅ Visual query builder - easier to understand and maintain
- ✅ Type safety - OutSystems validates data types
- ✅ No SQL compatibility issues (RIGHT, CASE syntax, etc.)
- ✅ Direct Server Action integration (GetPodFullName)
- ✅ Simpler for this use case (basic joins and aggregations)

**When to use SQL instead**:
- ❌ Complex CTEs with 10+ steps
- ❌ Window functions (SUM() OVER PARTITION BY)
- ❌ Timezone conversions (AT TIME ZONE)
- ❌ Scaffold patterns (CROSS JOIN for complete grids)
- ❌ Single-scan optimizations with conditional SUM

For Product Sales By Drawer, Aggregates are the right choice.
