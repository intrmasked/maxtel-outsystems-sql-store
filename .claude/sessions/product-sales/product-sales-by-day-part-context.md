# Session: Product Sales By Day Part (Parent Query) - 2025-12-18

## Original Story/Requirements

**User Request (exact):**
```
check the sessions get upto speed and tell me if we have this query

[User pasted complete SQL query for Product Sales by Day Part]

yeah make a folder for this query we have some work to do on this

dont want to revert as we need to handle all sites and having a list is the fastest way 
to handle that without handling the tenants control, so we let outsystems handle that 
give us a comma list for the sites available for a tenant, and then using that we get 
that data we need
```

**Context**:
- This is the **parent query** for the hourly drill-down view
- Child query already exists: `queries/reports/product-sales-by-day-part-hourly/`
- User wants multi-site support via comma-separated list (OutSystems handles tenant filtering)

---

## Status

- [X] Complete
- [ ] In Development
- [ ] In Testing
- [ ] Needs Review

**Current Version**: v8.2.0 - Complete Day Part Coverage (2026-01-20)

---

## v8.2.0 Implementation - Complete Day Part Coverage (2026-01-20)

**Problem**: 
Sites without data for specific day parts (e.g., no Overnight sales) would have those rows completely missing from query results, causing UI inconsistencies and unpredictable table layouts.

**Solution Implemented**:
- ✅ **DayPartMaster CTE** - Master list of all 4 day parts with labels and sort weights
- ✅ **SiteDateCombos CTE** - Extracts all unique site/date combinations from actual data
- ✅ **Complete Coverage** - CROSS JOIN ensures every site/date has all 4 day parts
- ✅ **Zero Filling** - COALESCE fills missing day parts with 0 values
- ✅ **Test File Updated** - `tests/test-ssms.sql` synced with main query

**New CTEs Structure**:
```
DayPartMaster → [4 rows: Overnight, Breakfast, Day, Night]
    ↓
SiteDateCombos → [All unique site/date combos from actual data]
    ↓
ActualDayPartAgg → [Aggregates only existing sales data]
    ↓
LabeledAgg → [CROSS JOIN all combos × all day parts, LEFT JOIN actual data]
```

**Impact**:
- UI consistently shows all 4 day parts for every site and date
- Missing day parts display: Value=0, PercentTotal=0, PercentInc=0
- Prevents table layout shifts
- All existing values unchanged (verified)

**Git Commit**: `fbd09a4` - feat(product-sales-by-day-part): ensure complete day part coverage for UI consistency (v8.2.0)

---

## Story 3572 Implementation (v4.1.0 - 2025-12-22)

**Requirements**: Add totals bar at top of screen showing aggregated values across ENTIRE filtered dataset.

**SOLUTION IMPLEMENTED**:
- ✅ **5 Grand Total rows** at position 0-4 (SortOrder -5 to -1)
- ✅ **GROUPING SETS optimization** - Single scan of CleanedData (was UNION ALL with 2 scans)
- ✅ **SiteName = 'Grand Totals'** for identification
- ✅ **PercentTotal = 100%** for Grand Total 'Total' row
- ✅ **Day part rows show % of Grand Total**
- ✅ **Test file created**: `tests/test-verify-grand-totals.sql`

**Grand Total Output Structure**:
| SortOrder | DayPartLabel | SiteName | PercentTotal |
|-----------|--------------|----------|--------------|
| -5 | Total | Grand Totals | 100% |
| -4 | Overnight (00-05) | Grand Totals | % of total |
| -3 | Breakfast (05-11) | Grand Totals | % of total |
| -2 | Day (11-17) | Grand Totals | % of total |
| -1 | Night (17-24) | Grand Totals | % of total |

**OutSystems Expression for Date Column**:
```
If(GetProductSalesByDayPart.Data.Current.SiteName = "Grand Totals",
   "Total",
   FormatDateTime(GetProductSalesByDayPart.Data.Current.Date, "ddd dd MMM"))
```

---

## Previous Implementation (v4.0.0)

**SOLUTION IMPLEMENTED (v4.0.0)**:
- ✅ **Expand Inline = YES** for @SiteIds parameter
- ✅ **Single-scan optimization** - Reads SalesFact ONCE for CY and PY
- ✅ **Pre-calculated timezone** - NZ conversion done before aggregation
- ✅ **Conditional aggregation** - YearType flag + CASE WHEN

---

## Tables Documentation Created

- `database-context/tables/SalesFact/` - [EXISTING]
- `database-context/tables/Site/` - [EXISTING]
  - **Critical Note**: Use `Site.Id` for SalesFact joins

---

## Queries Created

- `queries/reports/product-sales-by-day-part/` - [v8.2.0 - PRODUCTION READY]
  - Purpose: Parent query with Grand Totals + daily breakdown + complete day part coverage
  - Output: 5 Grand Total rows + 5 rows per day per site (all 4 day parts guaranteed)
  - Parameters: 
    - `@SiteIds` (NVARCHAR(MAX)) - ⚠️ **Expand Inline = YES** ⚠️
    - `@StartDate`, `@EndDate` (DATE)
    - `@SelectedView` (VARCHAR(1))

---

## Key Decisions

**v8.2.0 (2026-01-20) - Complete Day Part Coverage**:
- **DayPartMaster CTE**: Pre-defined list of all 4 day parts → Rationale: Guarantees complete coverage
- **CROSS JOIN Approach**: Site/Date combos × All day parts → Rationale: No missing rows in UI
- **COALESCE for zeros**: Fill missing data with 0 → Rationale: Consistent calculations
- **Performance**: Minimal impact (operates on already-aggregated tiny dataset)

**v4.1.0 (2025-12-22) - Story 3572**:
- **GROUPING SETS**: Single scan for all 5 totals → Rationale: Faster than UNION ALL (2 scans)
- **SiteName = 'Grand Totals'**: Clear identification in UI
- **PercentTotal = 100%**: Total row shows 100%, day parts show % of total
- **SortOrder < 0**: Negative values ensure grand totals appear first regardless of sorting

---

## Git Commits

**v8.2.0 (2026-01-20)**:
1. `fbd09a4` - feat(product-sales-by-day-part): ensure complete day part coverage for UI consistency (v8.2.0)

**Story 3572 (2025-12-22)**:

1. `7ec3fed` - Story 3572: Add Grand Total rows with GROUPING SETS optimization (v4.1.0)
2. `6ac6794` - Add test to verify grand totals calculation
3. `f6014c0` - Add 100% PercentTotal for Grand Total rows

---

## Quick Resume

1. **Check query**: `queries/reports/product-sales-by-day-part/query.sql` (v8.2.0)

2. **OutSystems Setup**:
   - `SiteIds` (Text) - ⚠️ **Expand Inline = YES** ⚠️
   - `StartDate`, `EndDate` (Date) - Expand Inline = No
   - `SelectedView` (Text) - Expand Inline = No

3. **Date column expression**:
   ```
   If(SiteName = "Grand Totals", "Total", FormatDateTime(Date, "ddd dd MMM"))
   ```

4. **Key Features**:
   - ✅ Grand Totals bar (5 rows at top)
   - ✅ Complete day part coverage (all 4 day parts always present)
   - ✅ Multi-site support
   - ✅ YoY comparison

---

## Related Queries

**Child Query**: `queries/reports/product-sales-by-day-part-hourly/query.sql`
- Single-day hourly breakdown (24 hours + Total Day)
- Status: Complete and finalized
