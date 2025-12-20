# Session: Product Sales By POS (Date Range) - 2025-12-09

## Original Story/Requirements

**User Request:**
User provided existing query code and requested: "make a folder for this query call is product-sales-by-pos"

**Query Purpose:**
Daily sales breakdown by Pod (Counter, Drive-Thru, Kiosk, Delivery) with year-over-year comparison over a date range. Supports multiple view modes (Sales, Guest Count, Average Check).

---

## Status

- [X] Complete
- [ ] In Development
- [ ] Needs Review

**Current step**: v2.2.3 - FIXED. Summary Row Double Counting Resolved. Duplicates Deduped.

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

## Latest Changes (2025-12-20) - INVESTIGATION & REFINEMENT

**v2.2.3 Changes (FINAL FIX):**
- **Excluded Summary Rows**: Added `AND PosId <> 0` to query.sql and test-ssms.sql. This killed the 2x double counting.
- **Deduplication Logic**: Maintained the `DedupedData` CTE with `MAX()` aggregation as a safety net against duplicates.

**v2.2.2 Changes:**
- Synced query logic strictly with granular test method.

**v2.2.1 Changes:**
- Implemented Dedup Logic.

---

## Technical Notes

**Performance Strategy:**
- UNION ALL approach for parallel CY+PY index seeks.
- Pre-aggregation before scaffold building.

**Debugging Notes:**
- "Parent vs Child" discrepancy was caused by Parent including `PosId=0` (Double Count) and Child only using `PosId=0` (Single Count).

---

## Quick Resume

1. **Query file**: `queries/reports/product-sales-by-pos/query.sql` (v2.2.3 - Clean & Deduped)
2. **SSMS test**: `queries/reports/product-sales-by-pos/tests/test-ssms.sql`
3. **Granular Test**: `queries/reports/product-sales-by-pos/tests/test-granular-view.sql` (Use this to verify data flow if confused).

---

## Related Queries

- **product-sales-by-pos-type-hourly**: Child query (hourly breakdown).
- **product-sales-by-day-part**: Similar multi-site pattern implemented.
