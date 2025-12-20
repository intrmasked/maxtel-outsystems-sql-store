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

**Current step**: v2.2.0 - Multi-site support with `SiteIds`, reverted to original filters (including PosId IS NOT NULL) to match original behavior, plus `SiteId` in output. Investigating data discrepancies.

---

## Latest Changes (2025-12-20) - INVESTIGATION & REFINEMENT

**v2.2.0 Changes:**
- **Reverted filters**: Restored `PosId IS NOT NULL` and other original filters to ensure data consistency with legacy query.
- **Added `SiteId` to output**: For UI linking/debugging.
- **Multi-site support**: Kept `@SiteIds` (Expand Inline = YES) and `SiteName` logic.
- **InputVar CTE**: Kept for OutSystems lazy parser fix.

**v2.0.0 Changes (Previous):**
- Changed `@SiteId BIGINT` → `@SiteIds NVARCHAR(MAX)` (comma-separated list)
- ⚠️ **CRITICAL**: `SiteIds` must have **Expand Inline = YES** in OutSystems!
- Added `SiteList` CTE with Site table join for display names
- Added `SiteName` column to output
- Created SSMS test file: `tests/test-ssms.sql`

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

## Previous Changes

**2025-12-10 - MAJOR PERFORMANCE OPTIMIZATION:**
- UNION ALL approach for parallel CY+PY index seeks (16x faster: 16s → 1s)
- Pre-aggregation before scaffold building
- RECOMPILE hint for optimal execution plan

**2025-12-10 - Dynamic Pod Detection:**
- ActivePods from AggregatedData (only CY activity)
- No hardcoded pod lists

---

## Quick Resume

**To continue this work:**

1. **Query file**: `queries/reports/product-sales-by-pos/query.sql` (v2.2.0)
2. **SSMS test**: `queries/reports/product-sales-by-pos/tests/test-ssms.sql`
3. **Status**: Multi-site support implemented, currently debugging data mismatch with child screens.

---

## Related Queries

- **product-sales-by-pos-type-hourly**: Child query (hourly breakdown).
- **product-sales-by-day-part**: Similar multi-site pattern implemented.
