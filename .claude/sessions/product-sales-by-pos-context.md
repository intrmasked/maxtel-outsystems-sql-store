# Session: Sales Reports (POS & Day Part) - 2025-12-09

## Original Story/Requirements

**User Request:**
1. "make a folder for this query call is product-sales-by-pos"
2. "check the daypart query and if we have that shit oging on there too fix that too" (2025-12-20)

**Query Purpose:**
Reporting queries for Daily Sales breakdown by different dimensions (POS/Pod and Day Part).

---

## Status

- [X] Complete
- [ ] In Development
- [ ] Needs Review

**Current step**: v2.2.4 (Day Part) & v2.2.3 (POS) - ALL FIXED.

> [!CAUTION]
> ### 🛑 SALESFACT TABLE KNOWLEDGE - READ THIS!
> We burned a lot of time debugging this. **Do not ignore these rules:**
>
> 1. **THE "DOUBLE COUNT" TRAP (`PosId = 0`)**
>    - `SalesFact` contains **both** Detailed Rows (`PosId > 0`) **AND** Pre-aggregated Summary Rows (`PosId = 0` / Service Charge Rows).
>    - **NEVER** use `PosId IS NOT NULL` alone. It grabs EVERYTHING and **doubles your report totals**.
>    - **ALWAYS** specify: `AND sf.PosId <> 0` (if you want Details) OR `WHERE PosId = 0` (if you want Summaries).
>
> 2. **DUPLICATE HEADERS (The "Overlap")**
>    - Even with valid filters, `SalesFact` can contain **duplicate/overlapping headers** for the same transaction (`SiteId` + `Date` + `PosId` + `DateTime`).
>    - If you `SUM(TransactionCount)`, you will inflate the count.
>    - **Safety Net**: Always `GROUP BY` the unique transaction key (`PosId`, `DateTime`) and use **`MAX()`** for `TransactionCount` and `NetAmount` before final aggregation.

---

## Latest Changes (2025-12-20)

**v2.2.4 - Product Sales By Day Part (SAFEGUARDED)**
- **Audit**: Query correctly targeted Summary Rows (`PosId=0`). No double counting found.
- **Safety Net**: Implemented `MAX()` deduplication logic anyway to protect against header overlaps in summary rows.
- **Output**: Added `SiteId` to final SELECT (as requested).
- **Testing**: Added `test-granular-view.sql` for 15-min interval visualization.

**v2.2.3 - Product Sales By POS (FIXED)**
- **Fix**: Excluded Summary Rows (`AND PosId <> 0`). Solved the "Double Counting" bug.
- **Safety Net**: Maintained `MAX()` deduplication.

---

## Technical Notes

**Performance Strategy:**
- UNION ALL approach for parallel CY+PY index seeks.
- Pre-aggregation before scaffold building.

**Debugging Notes:**
- "Parent vs Child" discrepancy was caused by Parent including `PosId=0` (Double Count) and Child only using `PosId=0` (Single Count).

---

## Quick Resume

1. **POS Query**: `queries/reports/product-sales-by-pos/query.sql`
2. **Day Part Query**: `queries/reports/product-sales-by-day-part/query.sql`
3. **Tests**: Check `tests/` folder in each query directory.
