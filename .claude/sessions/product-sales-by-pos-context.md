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

**Current step**: v2.2.0 - Data Discrepancy Investigation. Reverted filters to original state, added SiteId output. Created duplicate-check test.

---

## Latest Changes (2025-12-20) - INVESTIGATION & REFINEMENT

**v2.2.0 Changes:**
- **Reverted filters**: Restored `PosId IS NOT NULL` and others to match legacy query exactly.
- **Added `SiteId` to output**: For UI linking.
- **Diagnostic Scripts**:
  - `tests/test-verify-totals.sql`: Checks raw `SalesFact` totals vs query logic.
  - `tests/test-check-overlap.sql`: Checks for row duplication/double-counting in Parent Query logic.
- **SSMS Test Update**: `tests/test-ssms.sql` updated to match new output structure.

**v2.0.0 Changes (Previous):**
- Changed `@SiteId BIGINT` → `@SiteIds NVARCHAR(MAX)` (comma-separated list)
- ⚠️ **CRITICAL**: `SiteIds` must have **Expand Inline = YES** in OutSystems!
- Added `SiteList` CTE with Site table join for display names
- Added `SiteName` column to output

**OutSystems Setup:**
- `SiteIds` (Text) → **Expand Inline = YES**
- `StartDate` (Date) → Expand Inline = No
- `EndDate` (Date) → Expand Inline = No
- `SelectedView` (Text) → Expand Inline = No

**Output Structure:**
| Column | Type |
|--------|------|
| Date | Date |
| SiteId | Long Integer |
| SiteName | Text |
| Pod | Text |
| Value | Decimal |
| PercentTotal | Decimal |
| PercentInc | Decimal |
| SortOrder | Integer |

---

## Technical Notes

**Performance Strategy:**
- UNION ALL approach for parallel CY+PY index seeks (16s → 1s)
- Pre-aggregation before scaffold building
- RECOMPILE hint for optimal execution plan

**Debugging Notes:**
- "Parent vs Child" discrepancy observed.
- Parent Query filters: `Pod <> ''`, `PosId IS NOT NULL` (Active, Detailed transactions).
- Child Query filters (Day Part): `Pod = ''`, `PosId = 0` (Pre-aggregated/Special rows).
- **Hypothesis**: The reports read fundamentally different datasets.
- **Action**: Use `test-check-overlap.sql` to verify Parent query integrity (no double counting).

---

## Quick Resume

**To continue this work:**

1. **Query file**: `queries/reports/product-sales-by-pos/query.sql` (v2.2.0)
2. **Diagnostic Test**: `queries/reports/product-sales-by-pos/tests/test-check-overlap.sql`
3. **SSMS test**: `queries/reports/product-sales-by-pos/tests/test-ssms.sql`
4. **Status**: Investigating if Parent Query logic causes double counting (using overlap test).

---

## Related Queries

- **product-sales-by-pos-type-hourly**: Child query (hourly breakdown).
- **product-sales-by-day-part**: Similar multi-site pattern implemented.
