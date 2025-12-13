# Product Sales by Day Part - Hourly Drill-Down View

**Category**: Reports
**Created**: 2025-12-12
**Updated**: 2025-12-13
**Status**: Production Ready
**Author**: Claude (MaxTel SQL Store)

---

## Purpose

Provides comprehensive hourly sales breakdown for a single day with Sales, Guest Counts, and Average Check metrics displayed side-by-side. This matches the "Drill Down View" design showing all metrics for each hour with YoY comparison.

**Output**: 24 hourly rows (00-01 through 23-24) + 1 Total Day row = **25 rows total**

---

## Input Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `@SiteId` | BIGINT | Location ID | 3187 |
| `@Date` | DATE | Single date for hourly breakdown | 2025-11-25 |

**Note**: No @SelectedView parameter - all metrics (Sales, GCs, Ave Chq) are returned in a single query.

---

## OutSystems Setup

**IMPORTANT**: In OutSystems Advanced SQL Block, define these Input Parameters:

1. **SiteId** (Long Integer) - Set **Expand Inline = No**
2. **Date** (Date) - Set **Expand Inline = No**

OutSystems will automatically convert these to `@SiteId` and `@Date` in the SQL query.

**Do NOT include DECLARE statements** in the OutSystems query (lines 11-12 are for local testing only).

---

## Output Columns (9 columns)

| Column | Type | Description |
|--------|------|-------------|
| **Hour** | VARCHAR | Hour range label (e.g., "00-01", "01-02", ..., "Total Day") |
| **Sales** | DECIMAL(18,2) | Dollar sales (NetAmount) for this hour |
| **Sales_PctDay** | DECIMAL(18,2) | Sales as % of total daily sales |
| **Sales_PctInc** | DECIMAL(18,2) | YoY sales % increase (vs -364 days) |
| **GCs** | DECIMAL(18,0) | Guest Counts (TransactionCount) for this hour |
| **GCs_PctDay** | DECIMAL(18,2) | GCs as % of total daily GCs |
| **GCs_PctInc** | DECIMAL(18,2) | YoY GCs % increase (vs -364 days) |
| **AveChq** | DECIMAL(18,2) | Average Check (Sales / GCs) for this hour |
| **AveChq_PctInc** | DECIMAL(18,2) | YoY Ave Check % increase (vs -364 days) |

---

## Output Structure

The query returns **25 rows** for a single day:

**24 hourly rows** (SortOrder 0-23):
- 00-01, 01-02, 02-03, ..., 23-24

**1 Total Day row** (SortOrder 99):
- Total Day (sum of all 24 hours, appears last)

**Example Output** (1 Sep):

| Hour | Sales | Sales_PctDay | Sales_PctInc | GCs | GCs_PctDay | GCs_PctInc | AveChq | AveChq_PctInc |
|------|-------|--------------|--------------|-----|------------|------------|--------|---------------|
| 00-01 | 719.30 | 2.4 | 94.7 | 26 | 1.4 | 23.8 | 27.67 | 57.3 |
| 01-02 | 532.17 | 1.8 | 288.1 | 28 | 1.5 | 180.0 | 19.01 | 38.7 |
| 02-03 | 298.67 | 1.0 | 49.1 | 17 | 0.9 | 41.7 | 17.57 | 5.3 |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |
| 23-24 | 813.59 | 2.8 | 65.3 | 56 | 3.0 | 93.1 | 14.53 | -14.4 |
| **Total Day** | **######** | **100.0** | **61.5** | **1,869** | **100.0** | **37.8** | **15.75** | **17.1** |

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

### 2. Aggregate Level Filtering
- **Pod = ''** (empty string = site-wide aggregate)
- **ISNULL(PosId,0) = 0** (no specific POS = site-wide aggregate)
- **ProductSaleTypeId = 1** (product sales only)
- All other dimensions set to NULL (ProductMenuId, TenderTypeId, etc.)

### 3. Year-over-Year Comparison
- **Current Year**: CalendarDate = @Date
- **Previous Year**: CalendarDate = DATEADD(DAY, -364, @Date)
- Uses 364 days (52 weeks) to align day-of-week

### 4. Metrics Calculation

**Sales Metrics**:
- Sales = CY_NetAmount
- Sales_PctDay = (CY_NetAmount / GrandTotal_Net) * 100
- Sales_PctInc = ((CY_NetAmount - PY_NetAmount) / PY_NetAmount) * 100

**Guest Count Metrics**:
- GCs = CY_TransactionCount
- GCs_PctDay = (CY_TransactionCount / GrandTotal_Txn) * 100
- GCs_PctInc = ((CY_TransactionCount - PY_TransactionCount) / PY_TransactionCount) * 100

**Average Check Metrics**:
- AveChq = CY_NetAmount / CY_TransactionCount
- AveChq_PctInc = ((CY_Ave - PY_Ave) / PY_Ave) * 100

### 5. Total Row
- **Hour = "Total Day"**
- **Sales_PctDay = 100%** (sum of all hours)
- **GCs_PctDay = 100%** (sum of all hours)
- **AveChq = Total Sales / Total GCs** (weighted average)
- All YoY % increases calculated from totals

---

## Filters Applied

**SalesFact Mandatory Filters**:
```sql
WHERE SiteId = @SiteId
  AND CalendarDate IN (@Date, DATEADD(DAY, -364, @Date))
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

1. **InputVar CTE Pattern** - Fixes OutSystems "Lazy Parser" parameter binding issue
   - Pre-calculates CurrentDate, PrevDate, SiteIdVal
   - All parameters referenced through InputVars to avoid parsing failures

2. **Single Table Scan** - Fetches CY and PY data in one pass using conditional SUM
   - Uses `CalendarDate IN (@Date, DATEADD(DAY, -364, @Date))` filter
   - Conditionally aggregates with `SUM(CASE WHEN CalendarDate = ... THEN ... ELSE 0 END)`
   - Avoids double scan of SalesFact table

3. **Window Functions** - Calculates grand totals without extra joins
   - `MAX(CASE WHEN SortOrder = 99 ...) OVER()` pattern
   - Grand total available on every row for % calculations

4. **Hour Scaffold** - Ensures all 24 hours exist in output, even with 0 sales
   - LEFT JOIN pattern fills missing hours with 0 values

5. **RECOMPILE Hint** - `OPTION (RECOMPILE)` forces optimal execution plan
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
-- Get hourly breakdown for 1 Sep 2025
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-09-01';

-- Run the query
-- Returns 25 rows (24 hours + 1 Total Day row)
-- Output: Hour, Sales, Sales_PctDay, Sales_PctInc, GCs, GCs_PctDay, GCs_PctInc, AveChq, AveChq_PctInc
```

---

## Relationship to Parent Query

**Parent Query**: `queries/reports/product-sales-by-day-part/query.sql`
- Shows day parts: Total (00-24), Overnight (00-05), Breakfast (05-11), Day (11-17), Night (17-24)
- Date range support (multiple days)

**This Query (Hourly Drill-Down)**:
- Shows all metrics (Sales, GCs, Ave Chq) for **24 individual hours** + Total
- Single day only
- Total Day row should align with parent query's daily total
- Same filters (Pod = '', PosId = 0, ProductSaleTypeId = 1)

---

## Notes

- **OutSystems Compatible**: Uses `REPLICATE()` for hour formatting (no `RIGHT()` function)
- **InputVar CTE**: Handles OutSystems parameter binding quirk (required for long queries)
- **Timezone Handling**: Automatic daylight saving transition (NZDT vs NZST)
- **Hour Format**: "00-01", "01-02", ... matches UI display format
- **No SelectedView**: Unlike previous design, this query returns all metrics at once

---

## Testing

Test queries are located in `tests/` subfolder:
- `test-parameters.sql` - Parameter validation test

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-12 | Initial creation - Hourly breakdown query | Claude |
| 2025-12-13 | **COMPLETE REWRITE** - Changed to drill-down view with 9 columns (Sales/GCs/AveChq) | Claude |

---

## Related Documentation

- Parent Query: `queries/reports/product-sales-by-day-part/README.md`
- Table Docs: `database-context/tables/SalesFact/README.md`
- Session Context: `.claude/sessions/product-sales-by-day-part-hourly-context.md`
