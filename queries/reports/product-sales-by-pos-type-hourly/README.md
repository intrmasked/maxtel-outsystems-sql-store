# Query: Product Sales By POS Type Hourly

**Category**: Reports
**Created**: 2025-11-29
**Status**: In Development
**SQL Server**: 2014+ compatible
**Output Format**: Long format (one row per Hour-Pod combination)

---

## Purpose

Hourly sales breakdown by POS Type (Pod) with year-over-year comparison for a single day.

Shows:
- Sales performance by hour (00-01 through 23-24)
- Breakdown by Pod (Counter, Drive-Thru, Kiosk, Delivery, etc.)
- % of total for each pod within each hour
- Year-over-year growth % (vs same day 364 days ago)
- Total Day row matching parent screen totals

**Use Case**: Accessed from Product Sales By Register Type List screen when clicking a row.

---

## Output Format

**Long Format** - One row per Hour-Pod combination:

| Hour | Pod | Sales | PercentTotal | PercentInc |
|------|-----|-------|--------------|------------|
| 00-01 | CO | 150.50 | 25.0 | 5.2 |
| 00-01 | DT | 300.00 | 50.0 | -2.1 |
| 00-01 | KI | 100.00 | 16.7 | 10.5 |
| ... | ... | ... | ... | ... |
| 23-24 | CO | 200.00 | 30.0 | 8.0 |
| 23-24 | DT | 400.00 | 60.0 | 12.0 |
| Total Day | CO | 5000.00 | 40.0 | 8.5 |
| Total Day | DT | 6000.00 | 48.0 | 12.0 |

**Expected Row Count**: 24 hours × N pods + N pods (Total Day) = ~100 rows for 4 pods

---

## Parameters

### Required Parameters

- **@SiteId** (BIGINT): Site identifier (default: 3187)
- **@Date** (DATE): NZ Date for the report (single day, e.g., '2025-11-29')
- **@SelectedView** (VARCHAR(1)): View type
  - `'D'` = Dollar Sales (NetAmount)
  - `'G'` = Guest Count (TransactionCount)
  - `'A'` = Average Check (NetAmount / TransactionCount)

**To change parameters**: Edit the DECLARE statements at the top of query.sql

---

## Output Columns

| Column | Type | Description |
|--------|------|-------------|
| Hour | VARCHAR | Hour bucket (00-01, 01-02, ..., 23-24, Total Day) |
| Pod | VARCHAR | POS Type code (2-3 letters, e.g., CO, DT, KI, DL) |
| Sales | DECIMAL(18,2) | Value based on @SelectedView (NetAmount, TransactionCount, or Avg Check) |
| PercentTotal | DECIMAL(18,2) | % of total for this pod within this hour (0 for Average Check view) |
| PercentInc | DECIMAL(18,2) | Year-over-year growth % (vs 364 days ago) |

**Note**: OutSystems will use GetPODFullName action to convert Pod codes to full names (Counter, Drive-Thru, etc.)

---

## Calculations

### Sales Value (based on @SelectedView)
```
WHEN 'D' (Dollar): NetAmount
WHEN 'G' (Guest Count): TransactionCount
WHEN 'A' (Average Check): NetAmount / TransactionCount
```

### PercentTotal (Pod's % of hour total)
```
WHEN 'D': (Pod NetAmount / Hour Total NetAmount) * 100
WHEN 'G': (Pod TransactionCount / Hour Total TransactionCount) * 100
WHEN 'A': 0 (not applicable for average check)
```

### PercentInc (YoY Growth %)
```
((Current Year - Previous Year) / Previous Year) * 100

Previous Year = Same date 364 days ago (52 weeks back)
```

---

## Tables Used

- **SalesFact** - Transaction-level sales data
  - Filtered by: SiteId, CalendarDate, DatePeriodDimensionId = 15 (15-min intervals)
  - DateTime converted from UTC to NZ timezone
  - Grouped by Hour (extracted from NZ DateTime) and Pod

---

## Timezone Handling

**Critical**: Database stores DateTime in UTC, but report displays in NZ time.

**Conversion Pattern**:
```sql
DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time'))
```

- Automatically handles NZDT (UTC+13) and NZST (UTC+12) based on DST
- Hour extracted AFTER conversion to NZ timezone
- Ensures sales are bucketed by NZ business hours, not UTC hours

---

## Query Structure

### CTE Flow:

1. **Hours CTE**: Generate 24 hour buckets (0-23)
2. **AllPods CTE**: Get all distinct pods with data for this site/date
3. **Scaffold CTE**: Cross join Hours × Pods (ensures complete grid)
4. **CY_RawData CTE**: Current year data grouped by Hour, Pod
5. **PY_RawData CTE**: Prior year data (364 days back) grouped by Hour, Pod
6. **MergedData CTE**: Left join Scaffold with CY and PY data (fills gaps with 0)
7. **HourlyTotals CTE**: Sum all pods per hour for % Total calculation
8. **TotalDayData CTE**: Sum all hours for Total Day row
9. **TotalDayTotals CTE**: Totals for Total Day % calculations
10. **CombinedData CTE**: UNION hourly data with Total Day rows
11. **AllTotals CTE**: UNION hourly totals with Total Day totals
12. **Final SELECT**: Calculate Sales, PercentTotal, PercentInc

**Optimization**: Single query structure, no separate CY/PY queries at top level

---

## SalesFact Mandatory Filters

**Always Applied**:
```sql
AND DatePeriodDimensionId = 15       -- 15-minute intervals
AND ProductSaleTypeId = 1            -- Product sales only
AND ProductMenuId IS NULL
AND TenderTypeId IS NULL
AND OperationId IS NULL
AND OperationKindId IS NULL
AND SWCCashDrawerId IS NULL
AND SaleTypeId IS NULL
AND Pod IS NOT NULL                  -- Must have Pod
AND Pod <> ''                        -- Not empty
```

**Rationale**: Prevents double-counting in fact table aggregation

---

## Total Day Row

- **Hour**: 'Total Day'
- **SortOrder**: 9999 (appears last)
- **Values**: Sum of all 24 hours for each pod
- **Purpose**: Should match the parent screen's total for that date/pod

---

## Implementation Status

✅ **Complete**:
- Hourly breakdown (00-01 through 23-24)
- NZ timezone conversion from UTC
- Pod filtering and grouping
- YoY comparison (364 days back)
- Scaffold pattern (no missing Hour-Pod combinations)
- @SelectedView parameter (D/G/A)
- Total Day row
- Long format output

⏳ **Pending**:
- Testing with production data
- Validation of timezone conversions
- Verification of Pod codes
- Performance optimization if needed

---

## How to Use in OutSystems

1. Copy query to Advanced SQL Block in ProductSalesByRegisterTypeHoursScreen
2. Pass parameters:
   - `@SiteId` from parent screen
   - `@Date` from parent screen (selected row's date)
   - `@SelectedView` from View filter dropdown ('D', 'G', or 'A')
3. In datagrid, use GetPODFullName action to convert Pod codes to full names
4. Enable sorting by Hour (default) or other columns
5. Total Day row should match parent screen's total

---

## Performance Considerations

- **Single Day Query**: Optimized for single-day date range
- **15-min Data**: DatePeriodDimensionId = 15 provides granular hourly breakdown
- **Scaffold Pattern**: Ensures complete output even for hours with no sales
- **Index Recommendations**: See parent query (Product Sales By Drawer) for similar patterns

---

## Example Usage

```sql
-- View Dollar Sales by hour and pod
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';
DECLARE @SelectedView VARCHAR(1) = 'D';

-- Run query.sql
-- Expected output: ~100 rows (24 hours × 4 pods + 4 Total Day rows)
```

---

## Next Steps

- Test with actual production date
- Validate Pod codes against database
- Confirm timezone conversion accuracy
- Test all 3 views (D, G, A)
- Verify Total Day matches parent screen
