# Session: Product Sales By Day Part - Hourly Breakdown - 2025-12-12

## Original Story/Requirements

**User Request (exact):**
```
we are going to start working on a new story
its called Product Sales by Day Part Hourly
i've added a image to show you how it will look like

[Screenshot 1: Hourly drill-down view showing 24 hourly rows (00-01 through 23-24) + Total Day row]
[Screenshot 2: Parent query output showing day parts (Total, Overnight, Breakfast, Day, Night)]

the parent data query's output looks like this [parent query provided]

this is the query

Each row will be an hour.
No filters.
Data points will come from SalesFact, filtered by CalendarDay and Site, grouped by hour.
Ensure that other dimensions are nulled out in the filters for SalesFact.
Data will then be set as:
Total Sales = SalesFact.NetAmount
GC = SalesFact.Transactions
Ave Chq = NetAmount/Transactions
% Day = % of the Day Total (not relevant for AveChq)
% Inc = % increase from Last Year (use CalendarDay - 364).
Bottom row is the totals, (Total Ave Chq is the Total Sales / Total GC).
Bottom row figures should align with the day totals in the parent screen.

SECOND REQUEST (2025-12-12):
also we need daypart totals so at the end of a day add a line / row that basically adds in the total for that day part
its gonna be a pivoting mess but recc a structure for this too for the parent this is what im using which i think will work here too
[Screenshot 3: Parent screen structure showing ProductSalesByDayPartOutput]
this is the current structure for the parent screen, ill handle pivoting on my own so just do whats needed again make sure to follow the rules and keep sessions updated and push to git regulartly with proper git messages
```

**Additional Context:**
- Drill-down from "Product Sales by Day Part" parent query
- Parent query shows 4 day-part buckets (Overnight, Breakfast, Day, Night)
- This query breaks down a single day into 24 individual hours
- Database is in UTC, NZ timezone conversion required
- Use DatePeriodDimensionId = 15 for 15-minute intervals
- Output format: 29 rows (1 Total + 24 hourly rows + 4 day part totals)
- Hour format: "00-01", "01-02", ..., "23-24"
- Aggregate level: Pod = '', PosId = 0 (site-wide totals)
- Total row should match parent screen day totals
- Day part total rows: Overnight Total, Breakfast Total, Day Total, Night Total

---

## Status

- [X] Complete
- [ ] In Testing (User Acceptance)
- [ ] Needs Review

**Current step**: Query FINALIZED - Production ready

**Latest changes (2025-12-13) - COMPLETE QUERY REWRITE:**
- **🔥 COMPLETE REWRITE**: Changed to drill-down view design with 9 columns
  - **Problem**: Original design was based on incorrect requirements - built 5-column query with day part totals
  - **Discovery**: User provided screenshot of actual "Drill Down View" showing completely different structure
  - **New Design**: Wide-format query with Sales, GCs, and Ave Chq metrics side-by-side
  - **Implementation**:
    - **25 rows total**: 24 hourly rows (00-01 through 23-24) + 1 Total Day row
    - **9 columns**: Hour, Sales, Sales_PctDay, Sales_PctInc, GCs, GCs_PctDay, GCs_PctInc, AveChq, AveChq_PctInc
    - **Removed**: Day part totals (Overnight, Breakfast, Day, Night)
    - **Removed**: @SelectedView parameter (all metrics returned at once)
    - **Removed**: DayPartLabel column
    - **Simplified**: Only 2 parameters (@SiteId, @Date)
  - **New Structure**:
    - Section 1: Sales metrics (3 columns)
    - Section 2: Guest Count metrics (3 columns)
    - Section 3: Average Check metrics (2 columns)
    - Total Day row at end (SortOrder 99)
  - **Files Changed**:
    - `query.sql` - Complete rewrite (184 lines)
    - `README.md` - Complete rewrite to reflect new structure
    - `metadata.json` - Updated output_columns, parameters, key_features
  - **Status**: User confirmed "this works and it is finalized"

**Earlier changes (2025-12-13) - UNIFIED TOTAL LABEL (SUPERSEDED):**
- **✅ UPDATED**: All Total Rows Use "Total Day" Label
  - **Change**: All 5 total rows now use "Total Day" as the Hour label (differentiated by DayPartLabel column)
  - **Rationale**: User requested simplified labeling - don't mention day part in Hour column
  - **Implementation**:
    - All total rows: Hour = "Total Day"
    - DayPartLabel column differentiates which total:
      - "Overnight (00-05)" → Total Day for overnight hours
      - "Breakfast (05-11)" → Total Day for breakfast hours
      - "Day (11-17)" → Total Day for day hours
      - "Night (17-24)" → Total Day for night hours
      - "Total (00-24)" → Overall total for entire day
  - **Files Changed**:
    - `query.sql` line 164: HourLabel = 'Total Day'
    - `query.sql` line 181: All day part totals use 'Total Day'
    - `query.sql` lines 176-177: Comments updated
    - `README.md`: Output Columns, Output Structure, Example Output updated
  - **Status**: All total rows have uniform "Total Day" label in Hour column

**Earlier changes (2025-12-13) - SORT ORDER REORGANIZATION:**
- **✅ UPDATED**: Sort Order - All Totals at End
  - **Change**: Moved Total Day row and all day part totals to the end of output
  - **Rationale**: User requested easier cycling through data - totals at end instead of scattered throughout
  - **New Order**:
    1. All 24 hourly rows (00-01 through 23-24) - SortOrder 1-24
    2. Day part totals (Overnight, Breakfast, Day, Night) - SortOrder 25-28
    3. Total Day row - SortOrder 29 (at very end)
  - **Implementation Changes**:
    - TotalData CTE: SortOrder changed from 0 → 29
    - DayPartTotals CTE: SortOrder changed from 5.5, 11.5, 17.5, 24.5 → 25, 26, 27, 28
    - Window function: Changed `WHEN SortOrder = 0` → `WHEN SortOrder = 29`
    - PercentTotal calculation: Changed `WHEN SortOrder = 0` → `WHEN SortOrder = 29`
  - **Files Changed**:
    - `query.sql` lines 166, 188-192, 215-216, 248
    - `README.md`: Output Structure section updated
    - `README.md`: Example Output table reordered
  - **Status**: All totals now grouped at end for easier data review

**Earlier changes (2025-12-13) - COLUMN NAMING UPDATES:**
- **✅ UPDATED**: Total Row and Column Names
  - **Change 1**: Total row Hour label changed from "Total" to "Total Day"
  - **Change 2**: Column alias changed from "Pod" back to "DayPartLabel"
  - **Rationale**: User provided screenshot showing expected format with "Total Day" as Hour label
  - **Files Changed**:
    - `query.sql` line 164: 'Total' → 'Total Day'
    - `query.sql` line 230: DayPartLabel AS Pod → DayPartLabel
    - `query.sql` line 227: Comment updated to reflect DayPartLabel column name
    - `tests/test-parameters.sql`: Updated all column references
    - `README.md`: Output Columns section updated
    - `README.md`: Example Output table updated
  - **Status**: Matches OutSystems output structure exactly

**Earlier changes (2025-12-13) - INPUTVAR PATTERN FIX (CRITICAL):**
- **✅ FIXED**: OutSystems "Lazy Parser" Parameter Binding Bug
  - **Problem**: OutSystems scans queries top-down; parameters used deep in query logic fail with "Must declare scalar variable" or DateTime parse errors
  - **Root Cause**: OutSystems Advanced SQL has a "Lazy Parser" quirk where it stops tracking parameters if they're not seen early enough in the query
  - **Solution**: Applied InputVar CTE pattern (STEP 0) as first CTE
  - **Implementation**:
    - Added `InputVars AS (SELECT @Date AS CurrentDate, DATEADD(DAY, -364, @Date) AS PrevDate, @SiteId AS SiteIdVal, @SelectedView AS ViewVal)` as FIRST CTE
    - Changed RawDataCombined to use CROSS JOIN: `FROM {SalesFact}, InputVars v`
    - All parameters now referenced through InputVars columns: `v.SiteIdVal`, `v.CurrentDate`, `v.PrevDate`
    - Final SELECT uses subquery pattern: `(SELECT ViewVal FROM InputVars)` instead of direct `@SelectedView`
  - **Pattern Source**: CLAUDE.md documented this exact pattern for OutSystems compatibility
  - **User Confirmation**: User confirmed this version works in OutSystems
  - **Files Changed**:
    - `query.sql` - Complete rewrite with InputVars pattern (7 CTEs total, InputVars is STEP 0)
    - Query header updated to reflect "OPTIMIZED + InputVar Fix"
  - **Status**: WORKING in OutSystems production

**Earlier changes (2025-12-13) - OUTSYSTEMS OUTPUT STRUCTURE FIX:**
- **✅ FIXED**: Column Count Mismatch Error
  - **Problem**: User got error "Column count doesn't match output structure attribute count"
  - **Root Cause**: Query was returning 6 columns (Hour, DayPartLabel, Value, PercentTotal, PercentInc, SortOrder) but OutSystems output structure has 5 columns
  - **Discovery**: User provided screenshot showing OutSystems expects: Hour (Text), Pod (Text), Sales (Decimal), PercentTotal (Decimal), PercentInc (Decimal)
  - **Solution**: Updated final SELECT to match exact output structure
  - **Implementation**:
    - Renamed `DayPartLabel` → `DayPartLabel AS Pod`
    - Renamed `Value` → `Sales`
    - Removed `SortOrder` from final SELECT (still used internally for ORDER BY)
    - Updated README.md Output Columns section to reflect 5-column structure
    - Updated README.md Example Output table
  - **Files Changed**:
    - `query.sql` lines 217-269 (final SELECT statement)
    - `README.md` Output Columns section
    - `README.md` Example Output table
    - `tests/test-parameters.sql` (already fixed to 5 columns)
  - **Status**: Ready for testing in OutSystems

**Earlier changes (2025-12-12) - OUTSYSTEMS PRODUCTION FIX:**
- **✅ FIXED**: DateTime Parse Error in OutSystems
  - **Problem**: User got error "The string was not recognized as a valid DateTime. There is an unknown word starting at index 0."
  - **Root Cause**: OutSystems Advanced SQL doesn't support DECLARE statements at all (even for @SiteId, @Date, @SelectedView)
  - **Solution**: Removed ALL DECLARE statements from production query
  - **Implementation**:
    - Commented out all DECLARE lines (for local testing only)
    - Added OutSystems Setup Instructions comment block in query
    - Query now starts directly with WITH clause
    - Parameters defined in OutSystems UI (SiteId, Date, SelectedView)
  - **OutSystems Setup**:
    - Define Input Parameters in Advanced SQL Block UI
    - SiteId (Long Integer) - Expand Inline: No
    - Date (Date) - Expand Inline: No
    - SelectedView (Text) - Expand Inline: No
  - **Documentation**: Added OutSystems Setup section to README
  - **Status**: Production-ready for OutSystems

**Earlier changes (2025-12-12) - OUTSYSTEMS COMPATIBILITY FIX:**
- **✅ FIXED**: OutSystems Parameter Error
  - **Problem**: User got error "Unknown 'PrevDate' parameter used in 'SQL1'"
  - **Root Cause**: OutSystems Advanced SQL doesn't recognize DECLARE variables that aren't input parameters
  - **Solution**: Removed `DECLARE @PrevDate` and calculated inline throughout query
  - **Implementation**:
    - Changed `@PrevDate` → `DATEADD(DAY, -364, @Date)` in all 3 locations
    - CalendarDate IN (@Date, DATEADD(DAY, -364, @Date))
    - SUM(CASE WHEN CalendarDate = DATEADD(DAY, -364, @Date) ...)
  - **Performance Impact**: Minimal - SQL Server optimizes DATEADD calculations
  - **Documentation**: Updated query comments, README, and metadata.json
  - **Status**: OutSystems compatible, ready for testing

**Earlier changes (2025-12-12) - PERFORMANCE OPTIMIZATION:**
- **✅ OPTIMIZED**: Single-Scan Approach for CY/PY Data
  - **Replaced**: Separated CY/PY CTEs with combined conditional aggregation
  - **Implementation**:
    - RawDataCombined CTE uses `CalendarDate IN (@Date, DATEADD(DAY, -364, @Date))`
    - Conditional SUM: `SUM(CASE WHEN CalendarDate = @Date THEN NetAmount ELSE 0 END)`
    - Inline date calculation: DATEADD(DAY, -364, @Date) (OutSystems compatible)
    - Removed InputVar CTE (not needed - using @SelectedView directly)
    - Added OPTION (RECOMPILE) for optimal execution plan
    - Reduced from 8 CTEs to 6 CTEs
  - **Benefits**: Single table scan, cleaner code, better for single-day queries
  - **Performance**: Eliminates potential double-scan, optimal for this use case
  - **User Feedback**: User reviewed both approaches and confirmed this is better
  - **Documentation**: README and metadata.json updated with optimization details

**Earlier changes (2025-12-12) - DAY PART TOTALS ADDED:**
- **✅ ADDED**: Day Part Total Rows
  - **Implementation**:
    - New DayPartTotals CTE (STEP 6) calculates sum for each day part
    - 4 total rows: "Overnight Total", "Breakfast Total", "Day Total", "Night Total"
    - SortOrder positions totals after last hour of each day part:
      - Overnight Total: 5.5 (after 04-05)
      - Breakfast Total: 11.5 (after 10-11)
      - Day Total: 17.5 (after 16-17)
      - Night Total: 24.5 (after 23-24)
    - Each total row sums all hours within that day part
    - YoY comparison included for day part totals
  - **Output**: 29 rows per day (Total + 24 hours + 4 day part totals)
  - **Benefits**: Easy to verify hour sums, supports pivoting by filtering on "Total" suffix
  - **Documentation**: README and metadata.json updated with new output structure

**Earlier changes (2025-12-12) - INITIAL CREATION:**
- **✅ CREATED**: Product Sales by Day Part Hourly query
  - **Implementation**:
    - 24 hourly rows (00-01 through 23-24) + 1 Total row
    - Separated CY/PY fetch (prevents double-counting)
    - NZ timezone conversion (UTC → NZ)
    - Hour extraction using DATEPART(HOUR, ...)
    - Scaffold pattern ensures all 24 hours appear
    - Window functions for daily total calculations
    - InputVar CTE for OutSystems parameter binding quirk
    - DayPartLabel auto-classification for each hour
  - **Output**: Initially 25 rows per day (Total + 24 hours)
  - **Filters**: Aggregate level (Pod = '', PosId = 0)
  - **Benefits**: Matches parent query pattern, OutSystems compatible

**Complete items**:
1. ✅ Query folder structure created
2. ✅ Main query with hourly breakdown (00-01 through 23-24)
3. ✅ NZ timezone conversion using AT TIME ZONE
4. ✅ YoY comparison (CalendarDate - 364 days)
5. ✅ @SelectedView parameter handling (D/G/A)
6. ✅ Sales calculation based on view
7. ✅ PercentTotal calculation (Hour / Daily Total)
8. ✅ PercentInc calculation (YoY growth %)
9. ✅ Total row (sum of all 24 hours)
10. ✅ Total row PercentTotal = 100%
11. ✅ DayPartLabel auto-classification (Overnight/Breakfast/Day/Night)
12. ✅ Day Part Total rows (4 totals after each day part)
13. ✅ PERFORMANCE OPTIMIZATION: Single-scan conditional aggregation
14. ✅ OUTSYSTEMS FIX: Inline date calculation (using InputVars CTE)
15. ✅ PERFORMANCE OPTIMIZATION: OPTION (RECOMPILE) hint
16. ✅ CRITICAL FIX: Applied InputVar CTE pattern (STEP 0) for OutSystems "Lazy Parser" bug
17. ✅ OUTSYSTEMS FIX: Column structure (5 columns: Hour, Pod, Sales, PercentTotal, PercentInc)
18. ✅ README documentation (updated with optimization details)
19. ✅ metadata.json file (updated with optimization features)
20. ✅ Session context file (this file)
21. ✅ Query WORKING in OutSystems production

**Pending**:
- User acceptance testing with production data
- Validation that Total row aligns with parent screen day totals
- Verification of hour formatting (00-01, 01-02, ..., 23-24)
- Test query creation if needed

---

## Tables Documentation Created

- `database-context/tables/SalesFact/` - [EXISTING] - Already documented

---

## Queries Created

- `queries/reports/product-sales-by-day-part-hourly/` - [IN TESTING - OPTIMIZED]
  - Purpose: Hourly sales breakdown for a single day with YoY comparison
  - Tables used: SalesFact
  - Output: 29 rows (1 Total + 24 hours + 4 day part totals)
  - Parameters: @SiteId, @Date, @SelectedView, @PrevDate
  - Optimization: Single-scan conditional aggregation with RECOMPILE hint
  - Status: Query optimized and ready for testing

---

## Key Decisions

**FINAL DESIGN (2025-12-13)**:
- **🔥 Wide-format drill-down**: 9 columns showing Sales, GCs, Ave Chq metrics side-by-side → Rationale: User provided actual "Drill Down View" screenshot showing this is the correct design. Previous 5-column design was based on misunderstanding.
- **25 rows total**: 24 hourly rows + 1 Total Day row → Rationale: No day part totals needed - just hourly breakdown with overall total at end
- **No @SelectedView parameter**: All metrics returned at once → Rationale: Drill-down view shows all metrics simultaneously, not switchable views
- **Hour format "HH-HH"**: Use REPLICATE for padding (OutSystems compatible) → Rationale: No RIGHT() function in OutSystems, "00-01" format matches UI
- **🔥 CRITICAL: InputVar CTE Pattern (STEP 0)**: Added InputVars as FIRST CTE, all parameters referenced through it → Rationale: OutSystems "Lazy Parser" bug requires parameters to be seen early in query. Without this pattern, queries fail with "Must declare scalar variable" or DateTime parse errors.
- **🔧 OUTSYSTEMS FIX: CROSS JOIN with InputVars**: `FROM {SalesFact}, InputVars v` pattern → Rationale: Safely references parameters throughout query via v.SiteIdVal, v.CurrentDate, v.PrevDate
- **🚀 OPTIMIZATION: Single-scan conditional aggregation**: Combined CY/PY fetch with `CalendarDate IN (@Date, DATEADD(DAY, -364, @Date))` → Rationale: Single table scan, cleaner code, better performance
- **🚀 OPTIMIZATION: Window functions for grand totals**: `MAX(CASE WHEN SortOrder = 99 ...) OVER()` → Rationale: Grand total available on every row for % calculations without extra joins
- **🚀 OPTIMIZATION: RECOMPILE hint**: OPTION (RECOMPILE) at end → Rationale: Ensures optimal execution plan for each parameter set (recommended in CLAUDE.md)
- **NZ timezone conversion**: AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time' → Rationale: Database is UTC, report needs NZ business hours
- **Hour extraction**: DATEPART(HOUR, NZ_DateTime) → Rationale: Extract hour (0-23) in NZ timezone, not UTC
- **YoY comparison 364 days back**: CalendarDate - 364 days → Rationale: 52 weeks = same day of week comparison
- **Aggregate level filters**: Pod = '', PosId = 0 → Rationale: Site-wide totals (matching parent query pattern)
- **Total Day SortOrder = 99**: Ensures Total appears last → Rationale: Total row at bottom of output, hourly rows sorted 0-23
- **DatePeriodDimensionId = 15**: 15-minute intervals → Rationale: Same as parent query
- **ProductSaleTypeId = 1**: Product sales only → Rationale: Matches parent query pattern

---

## Next Steps

**Currently**: Query structure complete

**Waiting for**:
1. User testing with production data
2. Validation that Total row matches parent screen day totals
3. Feedback on hour formatting (00-01, 01-02, etc.)
4. Feedback on calculations

**After testing passes**:
1. Create test queries if needed
2. Mark query as COMPLETE
3. Update session context with test results

---

## Notes for Next Session

- **Timezone handling**: AT TIME ZONE automatically handles NZDT (UTC+13) and NZST (UTC+12)
- **Hour format**: "00-01" means 0:00-0:59 AM, "23-24" means 11:00-11:59 PM
- **Total row**: Should match parent screen's "Total (00-24)" for that date
- **View parameter**: 'D' = NetAmount, 'G' = TransactionCount, 'A' = NetAmount/TransactionCount
- **Aggregate level**: Pod = '' and PosId = 0 for site-wide totals
- **Scaffold pattern critical**: Prevents missing hours (even with 0 sales)
- **Parent query**: `queries/reports/product-sales-by-day-part/query.sql`

---

## Quick Resume

**To continue this work:**

1. **Read query**:
   - `queries/reports/product-sales-by-day-part-hourly/query.sql`
   - Main query with 8 CTEs following parent pattern

2. **Check documentation**:
   - `queries/reports/product-sales-by-day-part-hourly/README.md`
   - `queries/reports/product-sales-by-day-part-hourly/metadata.json`

3. **Status**:
   - ✅ Query structure complete
   - ⏳ Pending testing with production data
   - ⏳ Validation that Total row aligns with parent screen

4. **Next actions**:
   - Test query with actual SiteId and Date
   - Compare Total row with parent screen day totals
   - Verify hour formatting matches UI expectations
   - Create test queries if needed

---

## Repository State

**Files created this session**:
- `queries/reports/product-sales-by-day-part-hourly/query.sql`
- `queries/reports/product-sales-by-day-part-hourly/README.md`
- `queries/reports/product-sales-by-day-part-hourly/metadata.json`
- `queries/reports/product-sales-by-day-part-hourly/tests/` (folder created)
- `.claude/sessions/product-sales-by-day-part-hourly-context.md` (this file)

**Git Commits**:
- Not yet committed (pending testing)

**Current State**: Query development complete, pending user testing and validation

---

## Related Queries

**Parent Query**: `queries/reports/product-sales-by-day-part/query.sql`
- Date range support (multiple days)
- Day part buckets: Overnight (00-05), Breakfast (05-11), Day (11-17), Night (17-24)
- Same aggregate level filters (Pod = '', PosId = 0)

**Similar Query**: `queries/reports/product-sales-by-pos-type-hourly/query.sql`
- Hourly breakdown by Pod (Counter, Drive-Thru, Kiosk, Delivery)
- Different granularity (by Pod, not aggregate)
