# Session: Product Sales By POS Type Hourly - 2025-11-29

## Original Story/Requirements

**User Request (exact):**
```
A new screen is to be created within the Cash module Called Product Sales By Register Type Hourly. This will block will be ProductSalesByRegisterTypeHoursScreen.

The screen will use standard PageHeader_V4 with parent as "Product Sales By Register Type" and page title as [Site] + [Date].

When clicked into the Product Sales by Register Type menu option will be highlighted.

The screen will be accessed when clicking a row in the Product Sales By Register Type List screen.

The screen will use a datagrid to display a list of Sales data by hour.

The hours will cover a calendar day starting at 00-01 (midnight to 1am) and going to 23-24 (11pm - midnight).

The screen will have filters for:
View (options for Sales, GC, Av Chq

The data will display differently based on the View.

Data points will come from SalesFact, filtered by CalendarDay, Site and DateTime (using the 15min data):

Total Sales = SalesFact.NetAmount
Total %Inc = Salesfact.NetAmount % increase from Last Year (use CalendarDay - 364).

For each POD of Counter, Drivethru, Kiosk and Delivery: The SalesFacts need to be filtered by Pod.
Sales = NetAmount for that Pod.
% Total = % of that Pod.NetAmount / Total.NetAmount
(The % Total of the four Pods should total 100%)
% Inc = % increase from last year

Use the action GetPODFullName to derive "Counter" etc. from the Pod which will just be a 2-3 letter code.

For GC the same calculations are done except using SalesFact.TransactionCount rather than NetAmount.

Ave Chq will use the same except = SalesFact.NetAmount/SalesFact.Transaction Count.

For Ave Chq the % Total columns will be hidden because they wouldn't make sense in that context.

Columns are sortable (default is by Hour).

Totals row is at the bottom. (This should match the total on the parent screen for that day)
```

**Additional Context:**
- Database is in UTC, NZ timezone conversion required
- Use DatePeriodDimensionId = 15 for 15-minute intervals
- Output format: Long format (one row per Hour-Pod combination)
- User provided example query showing day-part pattern
- Screenshot shows desired table structure with Hour, Pod, Sales, %Total, %Inc columns

---

## Status

- [ ] Complete
- [ ] In Development
- [X] Ready for Testing (User Acceptance)
- [ ] Needs Review

**Current step**: Query optimized, DELIVERY pod support verified, ready for production testing

**Latest changes (2025-12-09) - DELIVERY Pod Support:**
- **✅ VERIFIED: DELIVERY pod support** - Query automatically includes DELIVERY pod
  - **How it works**: ActivePods CTE dynamically detects all pods from data
  - **No hardcoding needed**: Pod IN filter not used - picks up any pod in SalesFact
  - **Test files updated**: All test queries now support DELIVERY pod
    - test-1: Uses ActivePods (auto-detects DELIVERY)
    - test-2: Added DELIVERY to Pod IN filter
    - test-3: Uses ActivePods (auto-detects DELIVERY)
    - test-4: Added DELIVERY to Pod IN filter
    - test-5: Supports DELIVERY via @Pod parameter
- **🔗 Related work**: product-sales-by-pos query also updated for DELIVERY pod
  - Fixed PY_RawData CTE to include DELIVERY in Pod IN filter
  - Updated all test files with DELIVERY in Scaffold and Pod IN filters
- **📦 Git commit**: "Ensure DELIVERY pod included in all queries and tests" (7178ac7)

**Previous changes (2025-12-08) - FINAL VERSION:**
- **✅ FIXED: Hour 23 formatting** - Now displays as "23-24" instead of "23-00"
  - **Problem**: % 24 modulo caused hour 23 to show as "23-00"
  - **Solution**: Removed % 24 from hour formatting (line 92)
  - **Impact**: Matches OutSystems formula exactly
- **📊 INDEX RECOMMENDATIONS**: Added comprehensive index analysis to README
  - Critical index: IX_SalesFact_SiteId_DateTime_DatePeriodDim_Includes
  - Expected improvement: 9s → 1-2s (4-9x faster)
  - Includes DBA request template and OutSystems limitations documentation
- **🧪 DIAGNOSTIC TEST QUERY**: Created test-hourly-breakdown.sql
  - 5-part diagnostic for timezone/data validation
- **🔄 SIMPLIFIED**: Reverted to CalendarDate filtering for better performance
  - Uses CalendarDate filter (simpler than NZ Date conversion)
  - 8 CTEs with scaffold pattern (ensures all 24 hours appear)
  - Single database scan (CY and PY in one query)

**Earlier changes (2025-11-30):**
- **MAJOR UPDATE**: Added Total rows for each hour and Total Day
- Each hour now has 5 rows: Total + 4 individual pods (CO, DL, DT, KI)
- Total Day also has 5 rows: Total + 4 individual pods
- Output increased from ~100 rows to ~125 rows (24 hours × 5 + Total Day × 5)
- Total rows show Pod='Total' with PercentTotal=0
- Updated sorting to show Total first in each hour group

**Earlier changes (2025-11-29):**
- Created query folder structure
- Built main query with hourly breakdown
- Implemented NZ timezone conversion (UTC → NZ)
- Added YoY comparison (364 days back)
- Created scaffold pattern for all Hour-Pod combinations
- Implemented @SelectedView parameter (D/G/A)
- Added Total Day row per pod
- Created README and metadata files
- Fixed OutSystems compatibility issues (RIGHT → REPLICATE, CASE syntax)

**Complete items**:
1. ✅ Query folder structure created
2. ✅ Main query with hourly breakdown (00-01 through 23-24)
3. ✅ NZ timezone conversion using AT TIME ZONE (OPTIMIZED - converts once)
4. ✅ YoY comparison (CalendarDate - 364 days)
5. ✅ @SelectedView parameter handling (D/G/A)
6. ✅ Sales calculation based on view
7. ✅ PercentTotal calculation (Pod / Hour Total)
8. ✅ PercentInc calculation (YoY growth %)
9. ✅ Total Day row (sum of all hours per pod)
10. ✅ Long format output (one row per Hour-Pod)
11. ✅ **Hourly Total rows** (sum of all pods per hour)
12. ✅ **Total Day Total row** (sum of all pods for entire day)
13. ✅ README documentation (with index recommendations)
14. ✅ metadata.json file
15. ✅ **CalendarDate boundary fix** (hour 23-24 now appears) - 2025-12-08
16. ✅ **Query optimization** (8 CTEs → 5 CTEs, timezone conversion optimized) - 2025-12-08
17. ✅ **Index recommendations** (comprehensive analysis in README) - 2025-12-08
18. ✅ **Diagnostic test query** (test-hourly-breakdown.sql) - 2025-12-08

**Pending**:
- User acceptance testing with production data
- Index implementation (DBA review required)
- Performance validation (expect 9s → 1-2s with indexes)
- Verification that hour 23-24 now shows correctly

---

## Tables Documentation Created

- `database-context/tables/SalesFact/` - [EXISTING] - Already documented in product-sales-by-drawer query

---

## Queries Created

- `queries/reports/product-sales-by-pos-type-hourly/` - [IN DEVELOPMENT]
  - Purpose: Hourly sales breakdown by Pod with YoY comparison
  - Tables used: SalesFact
  - Output: Long format (Hour, Pod, Sales, PercentTotal, PercentInc)
  - Parameters: @SiteId, @Date, @SelectedView
  - Status: Query complete, pending testing

---

## Key Decisions

- **Long format output**: One row per Hour-Pod combination → Rationale: User screenshot shows list structure, OutSystems will handle GetPODFullName conversion
- **Total rows per hour**: Added Pod='Total' for each hour → Rationale: User screenshot shows "Total" column first, represents sum of all pods for that hour
- **Total Day Total row**: Added Pod='Total' for Total Day → Rationale: Grand total for entire day across all pods
- **PercentTotal = 0 for Total rows**: Total rows don't show % Total → Rationale: Total represents 100% already, individual pods show their % of Total
- **Sorting**: Total first (SortOrder - 0.5), then alphabetical pods → Rationale: User screenshot shows Total column on left side
- **Output structure**: ~24 hours × 5 rows + Total Day × 5 rows → Rationale: Total + CO + DL + DT + KI per hour (only hours with data)
- **🔴 REMOVED Scaffold pattern (2025-12-08)**: No longer using cross join Hours × Pods → Rationale: Simpler query, only shows hours with actual data (optimization)
- **🔴 CRITICAL: Filter by NZ Date not CalendarDate (2025-12-08)**: `CAST(CONVERT(...AT TIME ZONE...) AS DATE) = @Date` → Rationale: Fixes hour 23-24 boundary issue (UTC hour 23 = NZ next day)
- **🚀 OPTIMIZED: Convert timezone ONCE (2025-12-08)**: Store as NZ_DateTime in RawData CTE, reuse → Rationale: Was converting 6+ times per row, now converts once (major performance gain)
- **NZ timezone conversion**: AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time' → Rationale: Database is UTC, report needs NZ business hours
- **Hour extraction after TZ conversion**: DATEPART(HOUR, NZ_DateTime) → Rationale: Extract hour in NZ timezone, not UTC
- **YoY comparison 364 days back**: CalendarDate - 364 days → Rationale: 52 weeks = same day of week comparison
- **@SelectedView parameter**: 'D', 'G', 'A' → Rationale: Matches user's requirement for Sales/GC/Av Chq views
- **PercentTotal = 0 for Av Chq**: Not applicable for average check → Rationale: User specified "% Total columns will be hidden" for Av Chq view
- **Total Day SortOrder = 9999**: Ensures Total Day appears last → Rationale: Standard pattern for totals rows
- **DatePeriodDimensionId = 15**: 15-minute intervals → Rationale: User specified "using the 15min data"
- **ProductSaleTypeId = 1**: Product sales only → Rationale: Matches pattern from day-part example query
- **Pod IS NOT NULL and Pod <> ''**: Filter out empty pods → Rationale: Consistent with day-part pattern
- **🚀 OPTIMIZED: Single scan with conditional SUM (2025-12-08)**: Fetch CY and PY in one query → Rationale: Prevents double-counting, half the database reads
- **🚀 OPTIMIZED: NULLIF for divide-by-zero (2025-12-08)**: Simpler than nested CASE → Rationale: Cleaner code, same result

---

## Next Steps

**Currently**: Query structure complete

**Waiting for**:
1. User testing with production data
2. Validation of Pod codes (CO, DT, KI, DL, etc.)
3. Timezone conversion accuracy check
4. Feedback on calculations

**After testing passes**:
1. Create test queries (similar to product-sales-by-drawer tests)
2. Performance optimization if needed
3. Mark query as COMPLETE
4. Update session context with test results

---

## Notes for Next Session

- **Timezone handling**: AT TIME ZONE automatically handles NZDT (UTC+13) and NZST (UTC+12)
- **Output format**: Long format means OutSystems will pivot/group in UI
- **GetPODFullName**: OutSystems server action will convert Pod codes to full names
- **Total Day row**: Should match parent screen's total for that date
- **View parameter**: 'D' = NetAmount, 'G' = TransactionCount, 'A' = NetAmount/TransactionCount
- **No PosId filtering**: User confirmed "no need to include the posid"
- **Scaffold pattern critical**: Prevents missing Hour-Pod combinations
- **Example query provided**: Day-part query shows CTE pattern and timezone conversion

---

## Quick Resume

**To continue this work:**

1. **Read query**:
   - `queries/reports/product-sales-by-pos-type-hourly/query.sql`
   - Main query with 11 CTEs following day-part pattern

2. **Check documentation**:
   - `queries/reports/product-sales-by-pos-type-hourly/README.md`
   - `queries/reports/product-sales-by-pos-type-hourly/metadata.json`

3. **Status**:
   - ✅ Query structure complete
   - ⏳ Pending testing with production data
   - ⏳ Test queries not yet created

4. **Next actions**:
   - Test query with actual SiteId and Date
   - Validate Pod codes match database
   - Create test queries for validation
   - Verify timezone conversion accuracy

---

## Repository State

**Files created this session**:
- `queries/reports/product-sales-by-pos-type-hourly/query.sql`
- `queries/reports/product-sales-by-pos-type-hourly/README.md`
- `queries/reports/product-sales-by-pos-type-hourly/metadata.json`
- `.claude/sessions/product-sales-by-pos-type-hourly-context.md` (this file)

**Git Commits**:
- Not yet committed (pending testing)

**Current State**: Query development complete, pending user testing and validation
