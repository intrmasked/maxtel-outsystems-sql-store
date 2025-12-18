# Session: Product Sales By Day Part (Parent Query) - 2025-12-18

## Original Story/Requirements

**User Request (exact):**
```
check the sessions get upto speed and tell me if we have this query

[User pasted complete SQL query for Product Sales by Day Part]

yeah make a folder for this query we have some work to do on this
```

**Context**:
- This is the **parent query** for the hourly drill-down view
- Child query already exists: `queries/reports/product-sales-by-day-part-hourly/`
- Parent query was referenced in child's documentation but file didn't exist
- User provided the complete query code to set up

---

## Status

- [ ] Complete
- [X] In Development
- [ ] In Testing
- [ ] Needs Review

**Current step**: Blocked on comma-separated Site IDs parsing in OutSystems/SQL Server 2014

**Blocker**: Multiple parsing approaches attempted (STRING_SPLIT, XML, recursive CTE, Numbers table) all fail in OutSystems Advanced SQL environment. Need to revisit architecture - may need to revert to single @SiteId parameter or find OutSystems-compatible solution.

**Complete items (v4.0.0 - Single-Scan Optimization)**:
1. ✅ User implemented single-scan approach (reads SalesFact once instead of twice)
2. ✅ Pre-calculated timezone conversion before aggregation
3. ✅ Added YearType flag ('CY'/'PY') to classify rows in single scan
4. ✅ Used conditional aggregation with CASE WHEN to pivot CY/PY data
5. ✅ Added new indexes for optimal performance
6. ✅ Achieved 0.6s query performance (user-confirmed)

**Complete items (v3.0.0 - Refactor)**:
1. ✅ Removed @SiteId (nullable) and @ActiveOnly parameters
2. ✅ Added @SiteIds NVARCHAR(MAX) parameter (comma-separated list)
3. ✅ Removed SiteFilter CTE, added SiteList CTE with STRING_SPLIT()
4. ✅ Updated CY_RawData and PY_RawData to use IN clause
5. ✅ Updated all documentation (README, metadata.json)
6. ✅ Moved tenant/active filtering to OutSystems application layer

**Complete items (v2.0.0 - Multi-site)**:
1. ✅ Added multi-site support with @SiteId nullable parameter
2. ✅ Added @ActiveOnly boolean parameter for site filtering
3. ✅ Joined Site table for site names (Site.Id = SalesFact.SiteId)
4. ✅ Updated scaffold to Date x DayPart x Site grid
5. ✅ Updated window functions to partition by site
6. ✅ Created Site table documentation

**Pending items**:
1. Test query with production data
2. Validate multi-site output with @SiteIds
3. OutSystems integration (build comma-separated list)
4. Validate calculations per site

---

## Tables Documentation Created

- `database-context/tables/SalesFact/` - [EXISTING] - Already documented
- `database-context/tables/Site/` - [NEW] - Created 2025-12-18
  - Full documentation with Id vs Id_Site clarification
  - **Critical Note**: Use `Site.Id` for SalesFact joins (NOT Id_Site - that's for Xero tables)

---

## Queries Created

- `queries/reports/product-sales-by-day-part/` - [IN DEVELOPMENT - REFACTORED TO @SiteIds]
  - Purpose: Parent query showing sales by 4 day-part time buckets across date range and sites with YoY comparison
  - Tables used: SalesFact, Site (joined on Site.Id = SalesFact.SiteId)
  - Output: 5 rows per day per site (Total + 4 day parts: Overnight, Breakfast, Day, Night)
  - Format: Narrow format with switchable views (@SelectedView parameter)
  - Parameters: @SiteIds (comma-separated list), @StartDate, @EndDate, @SelectedView
  - Multi-Site: Accepts comma-separated Site IDs (e.g., '3187,3188,3189')
  - Tenant Filtering: Handled by OutSystems application layer (not in SQL)
  - Active Filtering: Handled by OutSystems application layer (not in SQL)
  - Relationship: Parent to product-sales-by-day-part-hourly (child drill-down)
  - Status: Refactored to cleaner @SiteIds approach, pending production testing
  - Version: 3.0.0 (upgraded from 2.0.0)

---

## Key Decisions

**Initial Setup (2025-12-18)**:
- **Date range support**: @StartDate to @EndDate (multi-day) → Rationale: Parent query covers multiple days, child drills into single day
- **Day part buckets**: 4 fixed time ranges → Rationale: Overnight (00-05), Breakfast (05-11), Day (11-17), Night (17-24)
- **View switching**: @SelectedView parameter toggles metric → Rationale: Single query handles Dollar/Guest/Average views
- **Numbers CTE**: Large date range support (10,000 days) → Rationale: Avoids recursion limit for long ranges
- **Separated CY/PY**: Independent CTEs for current/previous year → Rationale: Prevents double-counting from conditional logic
- **Scaffold pattern**: Date x DayPart grid → Rationale: Guarantees all rows exist (no missing data)
- **NZ timezone conversion**: AT TIME ZONE pattern → Rationale: Database is UTC, reports need NZ business hours
- **Aggregate level**: Pod = '', PosId = 0 → Rationale: Site-wide totals
- **YoY comparison**: -364 days (52 weeks) → Rationale: Same day-of-week alignment

**Multi-Site Enhancement (2025-12-18) - v2.0.0**:
- **Nullable @SiteId**: Changed from required to nullable (NULL = all sites) → Rationale: Support both single-site and multi-site reporting
- **@ActiveOnly parameter**: Added boolean flag (BIT) → Rationale: Filter active/inactive sites without changing query structure
- **Site table join**: Joined Site on `Site.Id = SalesFact.SiteId` → Rationale: Get site display names for output
- **CRITICAL - Id vs Id_Site**: Use `Site.Id` for internal joins, `Id_Site` only for Xero tables → Rationale: User clarified Id_Site is for external systems
- **SiteFilter CTE**: Pre-filter sites before joining to SalesFact → Rationale: INNER JOIN optimization, reduces join volume
- **Expanded scaffold**: Date x DayPart x Site (3-way CROSS JOIN) → Rationale: Ensure every site has all date/daypart combinations
- **Partitioned window functions**: PARTITION BY ReportDate, SiteId → Rationale: % calculations per site (not across all sites)
- **SiteName column**: Added to output using ISNULL(DisplayName, Name) → Rationale: Prefer DisplayName, fallback to Name
- **Sort order**: Date ASC, SiteName ASC, SortOrder ASC → Rationale: Logical grouping by date then site

**Refactor to @SiteIds Approach (2025-12-18) - v3.0.0**:
- **@SiteIds parameter**: Changed from @SiteId (nullable) to @SiteIds (NVARCHAR(MAX)) → Rationale: OutSystems handles tenant filtering, passes pre-filtered comma-separated list (faster, cleaner)
- **Removed @ActiveOnly**: No longer needed in SQL → Rationale: OutSystems application layer filters active/inactive sites before building @SiteIds list
- **Removed SiteFilter CTE**: Replaced with SiteList CTE → Rationale: No complex WHERE logic needed, just parse comma-separated string
- **SiteList CTE**: Uses STRING_SPLIT(@SiteIds, ',') → Rationale: Single operation to parse list into table, then join to Site for names
- **IN clause filtering**: `WHERE SiteId IN (SELECT SiteId FROM SiteList)` → Rationale: Fast lookup, SQL Server optimizes IN clause well
- **Clean separation of concerns**: Application layer = filtering, SQL = aggregation → Rationale: Better performance, cleaner code, no duplicate tenant logic
- **User feedback**: "doesn't automatically filter based on tenant like i thought" → Rationale: User realized OutSystems should handle tenant filtering, not SQL

**Single-Scan Optimization (2025-12-18) - v4.0.0**:
- **Single table scan**: Reads SalesFact once for both CY and PY data → Rationale: Eliminates duplicate table scans, SQL Server processes both date ranges in single operation
- **YearType flag**: Added 'CY'/'PY' classification column → Rationale: Tags each row in single scan, then pivots in aggregation phase
- **Pre-calculated timezone conversion**: `CONVERT(DATETIME, sf.[DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time') AS NZ_DateTime` → Rationale: Expensive operation performed once before aggregation instead of repeatedly in GROUP BY
- **Conditional aggregation**: `SUM(CASE WHEN YearType = 'CY' THEN NetAmount ELSE 0 END)` → Rationale: Single GROUP BY pivots CY/PY data without separate CTEs
- **New indexes**: User added optimized indexes → Rationale: Supports single-scan access pattern
- **Performance result**: 0.6 seconds (user-confirmed) → Significant improvement over v3.0.0 two-scan approach
- **User statement**: "check this out ive added new indexes this query works on 0.6s" → User has validated optimization in production environment

---

## Work Completed This Session (2025-12-18)

**OutSystems Compatibility Fixes (Attempted - BLOCKED)**:
1. ✅ Added InputVar CTE to fix OutSystems "lazy parser" bug for @SelectedView parameter
2. ✅ Replaced all direct `@SelectedView` references with `(SELECT SelectedView FROM InputVar)`
3. ❌ ATTEMPTED: STRING_SPLIT(@SiteIds, ',') → Error: "too many arguments" (requires SQL Server 2016+)
4. ❌ ATTEMPTED: XML parsing with CROSS APPLY .nodes() → Error: Multiple syntax errors in OutSystems
5. ❌ ATTEMPTED: Recursive CTE with CHARINDEX/STUFF → Error: "CHARINDEX requires 2-3 arguments"
6. ❌ ATTEMPTED: Numbers table approach with SUBSTRING → Still testing, errors persist
7. ⏳ BLOCKED: All comma-separated parsing methods fail in OutSystems/SQL Server 2014 environment

**Architecture Decision Needed**:
- Option A: Revert to single `@SiteId BIGINT` parameter (like all other queries in codebase)
- Option B: Find OutSystems-specific solution for comma-separated lists
- Option C: Move multi-site logic to OutSystems application layer (call query multiple times)

**Single-Scan Optimization (v4.0.0)**:
1. ✅ User implemented optimized single-scan query:
   - Eliminated separate CY_RawData and PY_RawData CTEs (two scans)
   - Combined into single SalesFact scan with YearType flag
   - Pre-calculated timezone conversion before aggregation
   - Used conditional aggregation to pivot CY/PY data
2. ✅ User added new indexes to support single-scan pattern
3. ✅ User tested and confirmed 0.6s performance
4. ✅ Updated session context to document v4.0.0 optimization milestone
5. ⏳ PENDING: Integration of optimized query into query.sql file (when user provides complete code)
6. ⏳ PENDING: Update README.md and metadata.json to document v4.0.0 changes

**Refactor to @SiteIds (v3.0.0)**:
1. ✅ Updated query.sql:
   - Changed `@SiteId BIGINT = NULL` → `@SiteIds NVARCHAR(MAX) = '3187,3188,3189'`
   - Removed `@ActiveOnly BIT` parameter
   - Removed SiteFilter CTE
   - Added SiteList CTE with `STRING_SPLIT(@SiteIds, ',')`
   - Updated Scaffold to use SiteList instead of SiteFilter
   - Updated CY_RawData: Removed `INNER JOIN SiteFilter`, added `WHERE SiteId IN (SELECT SiteId FROM SiteList)`
   - Updated PY_RawData: Removed `INNER JOIN SiteFilter`, added `WHERE SiteId IN (SELECT SiteId FROM SiteList)`
   - Updated query header comments to reflect new approach
2. ✅ Updated README.md:
   - Changed parameter documentation to @SiteIds
   - Removed @ActiveOnly from parameters table
   - Added note about OutSystems handling tenant/active filtering
   - Updated Data Sources section
   - Updated Multi-Site Support key feature
   - Updated Query Optimizations
   - Updated Usage Examples
   - Added OutSystems Setup with application-layer logic example
3. ✅ Updated metadata.json:
   - Version bumped to 3.0.0
   - Changed parameters (@SiteIds, removed @SiteId and @ActiveOnly)
   - Updated key_features
   - Updated performance techniques
   - Added v3.0.0 change_log entry
4. ✅ Updated session context with v3.0.0 refactor documentation

**Multi-Site Support Implementation (v2.0.0)**:
1. ✅ Created Site table documentation (`database-context/tables/Site/README.md`)
2. ✅ Updated query.sql:
   - Made @SiteId nullable (NULL = all sites)
   - Added @ActiveOnly BIT parameter
   - Added SiteFilter CTE (STEP 2.5)
   - Updated CY_RawData and PY_RawData to join SiteFilter
   - Expanded Scaffold to Date x DayPart x Site grid
   - Updated CleanedData and TotalData to include SiteId and SiteName
   - Added SiteName column to final output
   - Updated window functions to PARTITION BY ReportDate, SiteId
   - Updated sort order to Date ASC, SiteName ASC, SortOrder ASC
3. ✅ Updated README.md:
   - Added multi-site support description
   - Updated Input Parameters table
   - Updated Output Structure and Output Columns
   - Updated Example Output with SiteName
   - Added Multi-Site Support to Key Features
   - Updated Performance Considerations
   - Added usage examples for single-site and multi-site
4. ✅ Updated metadata.json:
   - Changed version from 1.0.0 to 2.0.0
   - Updated parameters (made @SiteId nullable, added @ActiveOnly)
   - Updated output_columns (added SiteName)
   - Updated tables_used (added Site table)
   - Updated key_features (added multi-site support)
   - Updated performance metrics
   - Added change_log entry for v2.0.0
5. ✅ Fixed Site table documentation:
   - Clarified Id (use for SalesFact) vs Id_Site (Xero tables only)
   - Updated all join examples
   - Updated all code snippets

## Next Steps

**Currently**: BLOCKED - Comma-separated Site IDs parsing fails in OutSystems/SQL Server 2014

**CRITICAL DECISION REQUIRED**:
1. **Choose architecture approach**:
   - A) Revert to single `@SiteId BIGINT` (proven, works in all existing queries)
   - B) Research OutSystems-specific comma-separated list handling
   - C) Handle multi-site in OutSystems app layer (for-each loop calling query multiple times)

**If Option A (Single SiteId) - RECOMMENDED**:
1. Revert query.sql to use `@SiteId BIGINT` parameter
2. Remove SiteList, SplitSiteIds, SiteIdNumbers CTEs
3. Use simple `WHERE SiteId = @SiteId` filter
4. Update README.md and metadata.json to reflect single-site approach
5. Test in OutSystems Advanced SQL block
6. Commit working version

**If Option B or C**:
1. Research OutSystems documentation for comma-separated parameter handling
2. Test alternative approaches
3. Document findings in session context

**After Unblocking**:
1. Integrate user's v4.0.0 single-scan optimization (if query structure compatible)
2. Test performance and validate output
3. Mark query as production-ready
4. Update status to Complete

---

## Notes for Next Session

- **Parent/Child Relationship**: This query is parent, hourly drill-down is child
- **Child query**: `queries/reports/product-sales-by-day-part-hourly/query.sql` (already complete and finalized)
- **Day part definitions**: Must match between parent and child for consistency
- **Timezone handling**: Same AT TIME ZONE pattern as child query
- **Aggregate level**: Same filters as child (Pod = '', PosId = 0)
- **User provided full query**: Query code came from user, not generated fresh
- **v4.0.0 Optimization**: User has optimized version achieving 0.6s with single-scan approach and new indexes
- **Performance**: 0.6s confirmed by user in production testing
- **Current file version**: query.sql contains v3.0.0 structure with attempted comma-separated parsing fixes
- **BLOCKER**: Comma-separated @SiteIds parsing incompatible with OutSystems/SQL Server 2014
- **InputVar CTE**: Successfully implemented to fix @SelectedView parameter binding issue
- **Recommendation**: Revert to single `@SiteId BIGINT` parameter (matches all other queries in codebase)

---

## Quick Resume

**To continue this work:**

1. **Read query**:
   - `queries/reports/product-sales-by-day-part/query.sql`
   - Current version: v3.0.0 (two-scan approach with separated CY_RawData and PY_RawData)
   - User has v4.0.0 optimized version (single-scan, 0.6s performance)

2. **Check documentation**:
   - `queries/reports/product-sales-by-day-part/README.md`
   - `queries/reports/product-sales-by-day-part/metadata.json`
   - Current version documented: v3.0.0

3. **Status**:
   - ✅ v1.0.0: Initial setup complete
   - ✅ v2.0.0: Multi-site support with SQL filtering
   - ✅ v3.0.0: Refactored to @SiteIds with application-layer filtering
   - ✅ v4.0.0: User optimized with single-scan approach (0.6s confirmed)
   - ⏳ PENDING: Integration of v4.0.0 into codebase
   - ⏳ TESTING: User validating v4.0.0 in production

4. **Next actions**:
   - Wait for user confirmation that testing is complete
   - If user provides complete v4.0.0 query code → integrate into query.sql
   - Update README.md and metadata.json to v4.0.0
   - Mark as production-ready when user confirms

---

## Repository State

**Files created this session**:
- `queries/reports/product-sales-by-day-part/query.sql` (Current: v3.0.0 structure with broken comma-separated parsing)
- `queries/reports/product-sales-by-day-part/README.md` (Current: v3.0.0, documents @SiteIds approach)
- `queries/reports/product-sales-by-day-part/metadata.json` (Current: v3.0.0, documents @SiteIds approach)
- `queries/reports/product-sales-by-day-part/tests/` (folder created, empty)
- `database-context/tables/Site/README.md` (created for multi-site support)
- `.claude/sessions/product-sales-by-day-part-context.md` (this file, updated with blocker documentation)

**Git Commits**:
- Pending: Will commit current state with blocker documentation

**Current State**:
- ❌ Query is BLOCKED - does not work in OutSystems Advanced SQL
- ✅ InputVar CTE fix applied successfully (fixes @SelectedView parameter)
- ❌ Comma-separated @SiteIds parsing incompatible with OutSystems/SQL Server 2014
- ⚠️ Multiple parsing approaches attempted, all failed (STRING_SPLIT, XML, recursive CTE, Numbers table)
- 📋 User has v4.0.0 optimization (single-scan, 0.6s) - pending compatible architecture
- 🔄 Recommendation: Revert to single `@SiteId BIGINT` parameter (proven approach in codebase)

---

## Related Queries

**Child Query**: `queries/reports/product-sales-by-day-part-hourly/query.sql`
- Single-day hourly breakdown (24 hours + Total Day)
- Wide-format output (9 columns, all metrics at once)
- Drills down from parent query's date selection
- Status: Complete and finalized (user confirmed)

**Similar Pattern**: `queries/reports/product-sales-by-pos-type-hourly/query.sql`
- Hourly breakdown by Pod (Counter, Drive-Thru, Kiosk, Delivery)
- Different granularity but similar structure
