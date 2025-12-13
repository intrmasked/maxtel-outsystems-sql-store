# Product Sales by Day Part - Hourly Breakdown

**Category**: Reports
**Created**: 2025-12-12
**Status**: In Testing
**Author**: Claude (MaxTel SQL Store)

---

## Purpose

Provides hourly sales breakdown for a single day, showing how sales are distributed across each hour (00-01, 01-02, ..., 23-24) with year-over-year comparison. This is a drill-down view from the main "Product Sales by Day Part" report.

**NEW**: Includes day part total rows (Overnight Total, Breakfast Total, Day Total, Night Total) that appear after the last hour of each day part for easy aggregation.

---

## Input Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `@SiteId` | BIGINT | Location ID | 3187 |
| `@Date` | DATE | Single date for hourly breakdown | 2025-11-25 |
| `@SelectedView` | VARCHAR(1) | Metric to display | 'D' |

**SelectedView Options**:
- `'D'` = Dollar Sales (NetAmount)
- `'G'` = Guest Count (TransactionCount)
- `'A'` = Average Check (NetAmount / TransactionCount)

---

## OutSystems Setup

**IMPORTANT**: In OutSystems Advanced SQL Block, you MUST define these Input Parameters:

1. **SiteId** (Long Integer) - Set **Expand Inline = No**
2. **Date** (Date) - Set **Expand Inline = No**
3. **SelectedView** (Text) - Set **Expand Inline = No**

OutSystems will automatically convert these to `@SiteId`, `@Date`, `@SelectedView` in the SQL query.

**Do NOT include DECLARE statements** in the OutSystems query. The query starts directly with the `WITH` clause.

**For local SQL Server testing only**, you can uncomment the DECLARE lines in the query file.

---

## Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `Hour` | VARCHAR | Hour range label (e.g., "00-01", "01-02", ..., "TotalDay") |
| `DayPartLabel` | VARCHAR | Auto-classified day part (Overnight/Breakfast/Day/Night/Total) |
| `Sales` | DECIMAL(18,2) | Sales metric based on @SelectedView |
| `PercentTotal` | DECIMAL(18,2) | Percentage of daily total (0 for Average view) |
| `PercentInc` | DECIMAL(18,2) | Year-over-year growth % (vs same day -364 days) |

---

## Output Structure

The query returns **29 rows** for a single day:
- **24 hourly rows**: 00-01, 01-02, ..., 23-24 (SortOrder 1-24, appears first)
- **4 day part total rows**: (SortOrder 25-28, after all hours)
  - "Overnight TotalDay"
  - "Breakfast TotalDay"
  - "Day TotalDay"
  - "Night TotalDay"
- **1 TotalDay row**: "TotalDay" (SortOrder 29, appears last)

**Example Output** (SelectedView = 'D'):

| Hour | DayPartLabel | Sales | PercentTotal | PercentInc |
|------|--------------|-------|--------------|------------|
| 00-01 | Overnight (00-05) | 535.24 | 2.93 | -2.45 |
| 01-02 | Overnight (00-05) | 0.00 | 0.00 | 0.00 |
| ... | Overnight (00-05) | ... | ... | ... |
| 04-05 | Overnight (00-05) | 120.50 | 0.66 | 1.23 |
| 05-06 | Breakfast (05-11) | 1250.30 | 6.84 | 3.12 |
| ... | Breakfast (05-11) | ... | ... | ... |
| 10-11 | Breakfast (05-11) | 980.25 | 5.36 | 2.45 |
| 11-12 | Day (11-17) | 3200.45 | 17.49 | 7.89 |
| ... | Day (11-17) | ... | ... | ... |
| 16-17 | Day (11-17) | 1100.80 | 6.02 | 4.12 |
| 17-18 | Night (17-24) | 2100.60 | 11.48 | 4.52 |
| ... | Night (17-24) | ... | ... | ... |
| 23-24 | Night (17-24) | 782.50 | 4.28 | 8.12 |
| **Overnight TotalDay** | **Overnight (00-05)** | **655.74** | **3.58** | **-1.85** |
| **Breakfast TotalDay** | **Breakfast (05-11)** | **2624.07** | **14.34** | **2.89** |
| **Day TotalDay** | **Day (11-17)** | **5629.06** | **30.77** | **6.54** |
| **Night TotalDay** | **Night (17-24)** | **9507.78** | **51.97** | **8.45** |
| **TotalDay** | **Total (00-24)** | **18296.15** | **100.00** | **5.23** |

---

## Tables Used

- **{SalesFact}** - Main fact table for sales transactions
  - Columns: `NetAmount`, `TransactionCount`, `DateTime`, `CalendarDate`, `SiteId`, `Pod`, `PosId`
  - Documentation: `database-context/tables/SalesFact/README.md`

---

## Key Logic

### 1. Hour Extraction (NZ Timezone)
- DateTime in SalesFact is stored in **UTC**
- Query converts to **NZ timezone** using `AT TIME ZONE`
- Extracts hour (0-23) using `DATEPART(HOUR, ...)`
- Hour buckets: 00-01 (0:00-0:59), 01-02 (1:00-1:59), ..., 23-24 (23:00-23:59)

### 2. DayPartLabel Auto-Classification
Each hour is automatically classified into a day part for easy extraction:
- **Overnight (00-05)**: Hours 0-4 (00-01, 01-02, 02-03, 03-04, 04-05)
- **Breakfast (05-11)**: Hours 5-10 (05-06, 06-07, 07-08, 08-09, 09-10, 10-11)
- **Day (11-17)**: Hours 11-16 (11-12, 12-13, 13-14, 14-15, 15-16, 16-17)
- **Night (17-24)**: Hours 17-23 (17-18, 18-19, 19-20, 20-21, 21-22, 22-23, 23-24)
- **Total (00-24)**: Total row (sum of all 24 hours)

This allows you to filter and aggregate by day part manually if needed.

### 3. Day Part Total Rows
After the last hour of each day part, a total row is inserted:
- **Overnight Total**: Sum of hours 00-01 through 04-05 (SortOrder 5.5, appears after 04-05)
- **Breakfast Total**: Sum of hours 05-06 through 10-11 (SortOrder 11.5, appears after 10-11)
- **Day Total**: Sum of hours 11-12 through 16-17 (SortOrder 17.5, appears after 16-17)
- **Night Total**: Sum of hours 17-18 through 23-24 (SortOrder 24.5, appears after 23-24)

These rows make it easy to:
- Compare day part performance without manual aggregation
- Verify that individual hours sum to day part totals
- Pivot data in OutSystems or Excel by filtering on "Total" suffix

### 4. Aggregate Level Filtering
- **Pod = ''** (empty string = site-wide aggregate)
- **ISNULL(PosId,0) = 0** (no specific POS = site-wide aggregate)
- **ProductSaleTypeId = 1** (product sales only)
- All other dimensions set to NULL (ProductMenuId, TenderTypeId, etc.)

### 5. Year-over-Year Comparison
- **Current Year**: CalendarDate = @Date
- **Previous Year**: CalendarDate = DATEADD(DAY, -364, @Date)
- Uses 364 days (52 weeks) to align day-of-week

### 6. Total Row Alignment
- **Total row should match parent screen day totals**
- Formula: SUM of all 24 hours
- Total row always has PercentTotal = 100%

---

## Filters Applied

**SalesFact Mandatory Filters**:
```sql
WHERE SiteId = @SiteId
  AND CalendarDate = @Date (or -364 for PY)
  AND DatePeriodDimensionId = 15
  AND ProductMenuId IS NULL
  AND ProductSaleTypeId = 1
  AND TenderTypeId IS NULL
  AND OperationId IS NULL
  AND OperationKindId IS NULL
  AND SWCCashDrawerId IS NULL
  AND SaleTypeId IS NULL
  AND Pod = ''
  AND ISNULL(PosId,0) = 0
```

---

## Performance Optimizations

**OPTIMIZED**: This query uses a single-scan approach for maximum efficiency on single-day queries.

1. **Single Table Scan** - Fetches both CY and PY data in one pass using conditional SUM aggregation
   - Uses `CalendarDate IN (@Date, DATEADD(DAY, -364, @Date))` filter
   - Conditionally aggregates with `SUM(CASE WHEN CalendarDate = @Date THEN ... ELSE 0 END)`
   - Avoids double scan of SalesFact table

2. **Inline Date Calculation** - `DATEADD(DAY, -364, @Date)` calculated inline
   - OutSystems compatible (no extra DECLARE parameters)
   - SQL Server optimizes this calculation automatically

3. **Early Filtering** - All dimension filters applied before aggregation for index pushdown
   - ProductMenuId, TenderTypeId, OperationId, etc. all set to NULL in WHERE clause
   - Enables SQL Server to use optimal indexes

4. **Window Functions** - Daily totals calculated using OVER() to avoid extra joins
   - `MAX(CASE WHEN SortOrder = 0 ...) OVER()` pattern
   - No additional table scans needed

5. **Hour Scaffold** - Ensures all 24 hours exist in output, even with 0 sales
   - LEFT JOIN pattern fills missing hours with 0 values

6. **RECOMPILE Hint** - `OPTION (RECOMPILE)` forces optimal execution plan
   - SQL Server optimizes for actual parameter values each run
   - Critical for queries with varying date ranges

---

## Index Recommendations

**Status**: Recommended (Pending DBA review)

1. **IX_SalesFact_SiteId_CalendarDate_DatePeriodDimensionId** (SiteId, CalendarDate, DatePeriodDimensionId)
   - Impact: High
   - Reason: Primary WHERE clause filtering
   - Status: Likely already exists (standard index)

2. **IX_SalesFact_Dimensions** (ProductMenuId, ProductSaleTypeId, TenderTypeId, OperationId, OperationKindId, SWCCashDrawerId, SaleTypeId)
   - Impact: Medium
   - Reason: Dimension NULL filtering
   - Status: Recommended if not exists

---

## Usage Example

```sql
-- Get hourly dollar sales breakdown for 2025-11-25
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-25';
DECLARE @SelectedView VARCHAR(1) = 'D';

-- Run the query
-- Returns 29 rows (1 Total + 24 hourly rows + 4 day part totals)
```

---

## Relationship to Parent Query

**Parent Query**: `queries/reports/product-sales-by-day-part/query.sql`
- Shows day parts: Total (00-24), Overnight (00-05), Breakfast (05-11), Day (11-17), Night (17-24)
- Date range support (multiple days)

**This Query (Hourly Drill-Down)**:
- Shows 24 individual hours for a **single day**
- Total row should match parent query's daily total
- Same filters (Pod = '', PosId = 0, ProductSaleTypeId = 1)

---

## Notes

- **OutSystems Compatible**: Uses `REPLICATE()` for hour formatting (no `RIGHT()` function)
- **InputVar CTE**: Handles OutSystems parameter binding quirk
- **Timezone Handling**: Automatic daylight saving transition (NZDT vs NZST)
- **Hour Format**: "00-01", "01-02", ... matches UI display format
- **Total Row First**: SortOrder = 0 ensures Total appears at top

---

## Testing

Test queries are located in `tests/` subfolder:
- `test-[feature].sql` - Feature-specific tests
- `test-diagnostic.sql` - Data verification tests

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-12 | Initial creation - Hourly breakdown query | Claude |

---

## Related Documentation

- Parent Query: `queries/reports/product-sales-by-day-part/README.md`
- Table Docs: `database-context/tables/SalesFact/README.md`
- Session Context: `.claude/sessions/product-sales-by-day-part-hourly-context.md`
