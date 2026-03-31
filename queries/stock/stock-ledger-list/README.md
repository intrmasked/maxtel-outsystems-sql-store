# Raw Stock — Summary List

**Feature**: 3.1 | **Depends on**: 2.1 (LogicalItemUsage)
**Route**: `Stock > Raw Stock`
**Created**: 2026-03-25
**Status**: In Progress

---

## Overview

One row per LogicalItem showing aggregated stock movements across a date range for the selected site(s). Starting Count comes from the first period, End Count from the last period, all other movement columns are summed.

A separate **Total Variance card** query runs across all pages (not just the current page) to show total Var $ and Var %.

---

## Queries

### 1. `query.sql` — GetRawStockList (Main)
List query. Returns one row per LogicalItem with:
- Starting Count (first period OpenQty)
- Summed: RawWaste, Deliveries, Transfers, UnitsCPM
- End Count (last period ActualClosedQty or TheoClosedQty)
- Variance: Qty, $, % (only when CloseQtyIsTheo = false)
### 2. `query-total-variance.sql` — GetRawStockTotalVariance
Same filters, returns:
- `TotalVarDollar` = SUM((Actual - Theo) * ItemCostAtClose) for qualifying rows
- `TotalVarPercent` = SUM(Actual - Theo) / SUM(TheoConsumed) * 100

Only rows where `CloseQtyIsTheo = false` on the last period qualify.

---

## Parameters

| Parameter | Type | Expand Inline | Notes |
|-----------|------|--------------|-------|
| `@SiteIds` | IntegerList | YES | One or more SiteIds |
| `@StartDate` | Date | No | Start of date range |
| `@EndDate` | Date | No | End of date range |
| `@ItemSearch` | Text | No | Optional LIKE filter on ItemName. NULL = no filter |
| `@ProductTypes` | TextList | YES | Optional. Food, Paper, Other. NULL = all |
| `@CountFrequencies` | IntegerList | YES | Optional. DefaultCountPeriodId values. NULL = all |

---

## Tables Used

| Table | Alias | Purpose |
|-------|-------|---------|
| StockPeriodBalance | SB | Core fact — quantities in portions |
| StockPeriod | SP | Site + Date filter |
| LogicalItem | LI | Item name, type, join keys |
| PhysicalItem | PI | UnitName, PortionsPerUnit conversion |
| CentralStockItem | CSI | DefaultCountPeriodId for frequency filter |

---

## Aggregation Rules

| Column | Rule |
|--------|------|
| Starting Count | `OpenQty` from **first** StockPeriod in range (not summed) |
| Raw Waste | `SUM(RawWasteQty)` across all periods |
| Deliveries | `SUM(DeliveredQty)` across all periods |
| Transfers | `SUM(TransferQty)` across all periods |
| Units CPM | `SUM(TheoConsumedQty)` across all periods |
| End Count | `ActualClosedQty` (or `TheoClosedQty` if CloseQtyIsTheo=true) from **last** period |
| Var Qty | `(ActualClosedQty - TheoClosedQty) / PortionsPerUnit` — last period only |
| Var $ | `Var Qty * ItemCostAtClose` — last period only |
| Var % | `(ActualClosedQty - TheoClosedQty) / TotalTheoConsumed * 100` |

---

## Theo-Derived Indicators

| Column | Condition | Display |
|--------|-----------|---------|
| Starting Count | `StartIsTheo = true` | Red italic `*` appended |
| End Count | `CloseQtyIsTheo = true` | Red italic `*` appended. Var Qty/$/% shown as `—` |

---

## Edge Cases

| Scenario | Behaviour |
|----------|-----------|
| `DefaultPhysicalItemId` is null | Row excluded (JOIN filters it out) |
| `TheoConsumedQty = 0` for all periods | Var % = NULL (blank) |
| `CloseQtyIsTheo = true` on last period | Var Qty/$/% all NULL. End Count shows TheoClosedQty |
| No rows in date range | Empty result. Variance card returns NULL/NULL |
| Single-day range | FirstDate = LastDate. Same row for start and end |

---

## Index Recommendations

**Status**: Recommended (Pending DBA review)

1. **IX_StockPeriod_SiteId_Date** (`SiteId`, `Date`)
   - Impact: High
   - Reason: Primary filter on every CTE — SiteId + Date range
   - Status: Recommended

2. **IX_StockPeriodBalance_StockPeriodId_LogicalItemId** (`StockPeriodId`, `LogicalItemId`)
   - Impact: High
   - Reason: JOIN key + GROUP BY in Bounds, Sums, FirstPeriod, LastPeriod CTEs
   - Status: Recommended

3. **IX_LogicalItem_ConceptId_WrinNumber** (`ConceptId`, `WrinNumber`)
   - Impact: Medium
   - Reason: JOIN to CentralStockItem
   - Status: Recommended

4. **IX_LogicalItem_DefaultPhysicalItemId** (`DefaultPhysicalItemId`)
   - Impact: Medium
   - Reason: JOIN to PhysicalItem
   - Status: Recommended

---

## File Structure

```
queries/stock/raw-stock-list/
├── query.sql                          # GetRawStockList (OutSystems production)
├── query-total-variance.sql           # GetRawStockTotalVariance (OutSystems production)
├── README.md                          # This file
├── metadata.json                      # Query metadata
├── output-structure.json              # Output structure for main query
├── output-structure-total-variance.json # Output structure for variance query
└── tests/
    ├── test-ssms.sql                  # Main query — SSMS version with DECLARE + STRING_SPLIT
    └── test-total-variance.sql        # Variance query — SSMS version
```
