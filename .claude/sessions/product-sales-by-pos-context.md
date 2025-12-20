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

**Current step**: v2.2.1 - Deduplication Logic VERIFIED. Test confirmed 0 duplicates after fix.

---

## Latest Changes (2025-12-20) - INVESTIGATION & REFINEMENT

**v2.2.1 Changes (FIX):**
- **Deduplication Logic Implemented**:
  - `RawDataPoints` now fetches `PosId` and `[DateTime]`.
  - Added `DedupedData` CTE: Groups by `(SiteId, Date, Pod, PosId, DateTime)` and uses `MAX()` aggregation.
  - This resolves the "duplicate header" issue where `TransactionCount` was inflated.
- **Verification Results**:
  - Before Fix: 484 duplicated transactions.
  - After Fix: 0 duplicated transactions ✅.
  - Excess columns removed: 861.

**v2.2.0 Changes:**
- **Reverted filters**: Restored `PosId IS NOT NULL` and others to match legacy query exactly.
- **Added `SiteId` to output**: For UI linking.
- **Diagnostic Scripts**:
  - `tests/test-verify-totals.sql`: Checks raw `SalesFact` totals vs query logic.
  - `tests/test-check-overlap.sql`: Confirmed duplicate rows in `SalesFact`.

---

## Technical Notes

**Performance Strategy:**
- UNION ALL approach for parallel CY+PY index seeks.
- Pre-aggregation before scaffold building.
- **Deduplication Cost**: Grouping by `PosId` + `DateTime` adds a bit of overhead, but necessary for correctness.

**Debugging Notes:**
- "Parent vs Child" discrepancy was caused by duplicate rows in `SalesFact` matching the Parent Query filters.
- `MAX()` aggregation is used for deduping because duplicate headers typically repeat the same total values.

---

## Quick Resume

**To continue this work:**

1. **Query file**: `queries/reports/product-sales-by-pos/query.sql` (v2.2.1 - Deduped)
2. **SSMS test**: `queries/reports/product-sales-by-pos/tests/test-ssms.sql`
3. **Verify**: Run `queries/reports/product-sales-by-pos/tests/test-verify-totals.sql` to confirm fix.

---

## Related Queries

- **product-sales-by-pos-type-hourly**: Child query (hourly breakdown).
- **product-sales-by-day-part**: Similar multi-site pattern implemented.
