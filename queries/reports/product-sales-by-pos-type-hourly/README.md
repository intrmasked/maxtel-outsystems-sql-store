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
- **Timezone Conversion**: Optimized to convert ONCE per row and reuse
- **Single Database Scan**: Fetches CY and PY data in one pass
- **Current Performance**: ~9 seconds (can be improved with indexes below)

---

## Index Recommendations

**Status**: Recommended (Requires Database Administrator)

**⚠️ IMPORTANT - OutSystems Limitation:**
- **OutSystems does NOT support creating database indexes directly**
- Indexes must be created manually by Database Administrator using SQL Server Management Studio (SSMS)
- OutSystems Service Center only manages entity/table structure, not indexes
- This is a **SQL Server database-level optimization**, not an OutSystems application change

**How to Implement:**
1. Contact your Database Administrator (DBA)
2. Provide the index scripts below
3. DBA creates indexes in SQL Server (DEV → TEST → PROD)
4. Verify performance improvement after index creation

---

### 🔥 Critical Index (High Impact) - RECOMMENDED

**Index Name:** `IX_SalesFact_SiteId_DateTime_DatePeriodDim_Includes`

**SQL Script for DBA:**
```sql
-- Execute this in SQL Server Management Studio (SSMS)
-- Database: [YourDatabaseName]
-- Table: SalesFact

CREATE NONCLUSTERED INDEX IX_SalesFact_SiteId_DateTime_DatePeriodDim_Includes
ON dbo.SalesFact (SiteId, DateTime, DatePeriodDimensionId)
INCLUDE (Pod, NetAmount, TransactionCount, ProductSaleTypeId, ProductMenuId,
         TenderTypeId, OperationId, OperationKindId, SWCCashDrawerId, SaleTypeId)
WITH (ONLINE = ON, FILLFACTOR = 90);
-- ONLINE = ON: Allows table to remain accessible during index creation
-- FILLFACTOR = 90: Leaves 10% space for updates (reduces page splits)
```

**Why This Index:**
- Covers WHERE clause filters (SiteId, DateTime range via timezone conversion, DatePeriodDimensionId = 15)
- INCLUDE clause covers all SELECT and additional WHERE columns
- Enables index-only scan (no table lookup needed)
- **Expected Impact**: 9 seconds → 1-2 seconds (4-9x faster)

**Columns Used:**
- **Key Columns**: SiteId (filter), DateTime (timezone conversion + range), DatePeriodDimensionId (filter)
- **Included Columns**: Pod (GROUP BY), NetAmount (SUM), TransactionCount (SUM), all IS NULL filters

**Index Size Estimate:** ~50-100 MB (depending on data volume)

---

### 📊 Alternative Index (If above is too large)

**Index Name:** `IX_SalesFact_SiteId_DatePeriodDim_DateTime`

**SQL Script for DBA:**
```sql
-- Simpler version with fewer INCLUDE columns
CREATE NONCLUSTERED INDEX IX_SalesFact_SiteId_DatePeriodDim_DateTime
ON dbo.SalesFact (SiteId, DatePeriodDimensionId, DateTime)
INCLUDE (Pod, NetAmount, TransactionCount)
WITH (ONLINE = ON, FILLFACTOR = 90);
```

**Why:**
- Smaller index size (fewer INCLUDE columns)
- Still covers main filters and aggregations
- **Expected Impact**: 9 seconds → 2-4 seconds (2-4x faster)

**Index Size Estimate:** ~20-40 MB

---

### 🎯 Index Effectiveness Analysis

**Current Query Filter Pattern**:
```sql
WHERE SiteId = @SiteId                                      -- ✅ Indexed (key column)
  AND DatePeriodDimensionId = 15                            -- ✅ Indexed (key column)
  AND CAST(CONVERT(... AT TIME ZONE ...) AS DATE) IN (...)  -- ✅ Uses DateTime (key column)
  AND Pod IS NOT NULL AND Pod <> ''                         -- ✅ Indexed (INCLUDE)
  AND ProductSaleTypeId = 1                                 -- ✅ Indexed (INCLUDE)
  AND ProductMenuId IS NULL                                 -- ✅ Indexed (INCLUDE)
  AND TenderTypeId IS NULL                                  -- ✅ Indexed (INCLUDE)
  AND OperationId IS NULL                                   -- ✅ Indexed (INCLUDE)
  AND OperationKindId IS NULL                               -- ✅ Indexed (INCLUDE)
  AND SWCCashDrawerId IS NULL                               -- ✅ Indexed (INCLUDE)
  AND SaleTypeId IS NULL                                    -- ✅ Indexed (INCLUDE)
```

**GROUP BY Columns**: Pod (INCLUDE), DATEPART(HOUR, NZ_DateTime) (computed from DateTime)
**Aggregate Columns**: NetAmount (INCLUDE), TransactionCount (INCLUDE)

---

### 📈 Performance Expectations

| Scenario | Without Index | With Simple Index | With Full Index |
|----------|--------------|-------------------|-----------------|
| **Current** | 9 seconds | ~2-4 seconds | ~1-2 seconds |
| **Busy Site** | 15+ seconds | ~3-6 seconds | ~1-3 seconds |
| **Low Traffic Site** | 5 seconds | ~1-2 seconds | <1 second |

---

### ⚙️ Index Maintenance Notes

- **Rebuild Schedule**: Weekly (SalesFact is heavily written to)
- **Fragmentation Check**: Monitor monthly
- **Fill Factor**: Consider 90% (allows for updates without excessive page splits)
- **Statistics**: Update after nightly data loads

---

### 🧪 How to Test Index Impact

**Step 1: Check if Index Already Exists**
```sql
-- Run this in SSMS to check existing indexes on SalesFact
SELECT
    i.name AS IndexName,
    OBJECT_NAME(i.object_id) AS TableName,
    COL_NAME(ic.object_id, ic.column_id) AS ColumnName,
    ic.is_included_column AS IsIncludedColumn
FROM sys.indexes i
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
WHERE OBJECT_NAME(i.object_id) = 'SalesFact'
    AND i.name LIKE '%SiteId%'
ORDER BY i.name, ic.key_ordinal;
```

**Step 2: Before Index**
```sql
SET STATISTICS TIME ON;
-- Run your query here (query.sql)
SET STATISTICS TIME OFF;
-- Note the execution time in milliseconds
```

**Step 3: Create Index**
- Apply recommended index in DEV environment first
- Use SSMS to execute CREATE INDEX script
- Monitor index creation progress

**Step 4: After Index**
```sql
SET STATISTICS TIME ON;
-- Run same query again
SET STATISTICS TIME OFF;
-- Compare execution time
```

**Step 5: Verify Index Usage**
```sql
SET SHOWPLAN_XML ON;
-- Run query
SET SHOWPLAN_XML OFF;
-- Check execution plan - should see "Index Seek" on the new index, not "Table Scan"
```

**Expected Results:**
- Before: ~9,000ms (9 seconds)
- After: ~1,000-2,000ms (1-2 seconds)
- Improvement: 4-9x faster

---

### 🚨 Index Priority

**High Priority**: This query runs every time user clicks into hourly detail screen
- **User Impact**: Direct UX - 9 second wait is noticeable
- **Recommendation**: Implement ASAP in production
- **Risk**: Low - read-only query, index only affects reads

---

### 📋 DBA Request Template

**Copy this template when requesting index from DBA:**

```
Subject: Index Request - SalesFact Table (Product Sales By POS Type Hourly Query)

Hi [DBA Name],

We have a performance issue with the Product Sales By POS Type Hourly report in OutSystems.

Current Performance: ~9 seconds per query
Expected Performance: 1-2 seconds with index

Request: Create the following index on the SalesFact table

Index Name: IX_SalesFact_SiteId_DateTime_DatePeriodDim_Includes

Script:
CREATE NONCLUSTERED INDEX IX_SalesFact_SiteId_DateTime_DatePeriodDim_Includes
ON dbo.SalesFact (SiteId, DateTime, DatePeriodDimensionId)
INCLUDE (Pod, NetAmount, TransactionCount, ProductSaleTypeId, ProductMenuId,
         TenderTypeId, OperationId, OperationKindId, SWCCashDrawerId, SaleTypeId)
WITH (ONLINE = ON, FILLFACTOR = 90);

Environment: DEV first, then TEST, then PROD
Priority: High (user-facing performance issue)
Impact: Read-only optimization, no data changes

Query Location: maxtel-outsystems-sql-store/queries/reports/product-sales-by-pos-type-hourly/query.sql
Documentation: See README.md in same folder

Please let me know if you need any additional information.

Thanks,
[Your Name]
```

---

### 💡 OutSystems Best Practices for Database Indexes

**What OutSystems CAN Do:**
- Create database tables (entities)
- Add/remove columns (attributes)
- Create relationships (foreign keys)
- Generate basic indexes on primary keys

**What OutSystems CANNOT Do:**
- Create custom non-clustered indexes
- Add INCLUDE columns to indexes
- Set FILLFACTOR or other index options
- Optimize existing indexes

**Workaround:**
- **Manual Index Management**: All custom indexes must be created by DBA outside OutSystems
- **OutSystems Deployments**: Indexes persist during deployments (OutSystems doesn't drop custom indexes)
- **Index Tracking**: Document all custom indexes in query README files (like this one)

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
