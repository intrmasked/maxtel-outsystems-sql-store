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

**Current step**: v2.0.0 complete - Multi-site support added and tested in OutSystems

---

## Latest Changes (2025-12-19) - MULTI-SITE SUPPORT v2.0.0

**Key Changes:**
- Changed `@SiteId BIGINT` → `@SiteIds NVARCHAR(MAX)` (comma-separated list)
- ⚠️ **CRITICAL**: `SiteIds` must have **Expand Inline = YES** in OutSystems!
- Added `SiteList` CTE with Site table join for display names
- Added `SiteName` column to output
- Updated all GROUP BY, PARTITION BY, ORDER BY to include SiteId/SiteName
- Added `InputVar` CTE for @SelectedView and @EndDate (OutSystems lazy parser fix)
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

1. **Query file**: `queries/reports/product-sales-by-pos/query.sql` (v2.0.0)
2. **SSMS test**: `queries/reports/product-sales-by-pos/tests/test-ssms.sql`
3. **Status**: Multi-site support complete, tested in OutSystems

---

## Related Queries

- **product-sales-by-pos-type-hourly**: Hourly version (may need same multi-site update)
- **product-sales-by-day-part**: Similar multi-site pattern implemented
