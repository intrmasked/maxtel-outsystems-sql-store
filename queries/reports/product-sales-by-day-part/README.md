# Product Sales By Day Part

**Category**: Reports
**Created**: 2025-12-18
**Status**: Production Ready (v4.1.0)

## Purpose

Returns sales/transaction data grouped by 4 day-part time buckets across a date range and sites. Shows how sales are distributed across different times of day with year-over-year comparison. Supports multi-site reporting with tenant filtering handled by OutSystems application layer. This is the parent query for the hourly drill-down view.

## Business Context

- **Use Case**: Analyze sales patterns by time of day across multiple days and sites
- **Audience**: Store managers, operations team, multi-site analysts
- **Refresh Frequency**: Daily
- **Multi-Site Support**: Accepts comma-separated list of Site IDs (tenant filtering done by OutSystems)
- **Related Query**: Drill down to `product-sales-by-day-part-hourly` for single-day hourly breakdown

## Day Part Definitions

| Day Part | Time Range | Description |
|----------|-----------|-------------|
| **Overnight (00-05)** | 0:00 AM - 4:59 AM | Graveyard shift sales |
| **Breakfast (05-11)** | 5:00 AM - 10:59 AM | Morning service |
| **Day (11-17)** | 11:00 AM - 4:59 PM | Lunch & afternoon |
| **Night (17-24)** | 5:00 PM - 11:59 PM | Dinner & evening |

## Input Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `@SiteIds` | NVARCHAR(MAX) | Comma-separated list of Site IDs<br>**OutSystems handles tenant filtering** | '3187,3188,3189' |
| `@StartDate` | DATE | Start of date range | '2025-12-01' |
| `@EndDate` | DATE | End of date range | '2025-12-07' |
| `@SelectedView` | VARCHAR(1) | Metric to display | 'D' = Dollar Sales<br>'G' = Guest Count<br>'A' = Average Check |

**Note**: `@SiteIds` is pre-filtered by OutSystems based on tenant and active/inactive status. The SQL query does not perform tenant filtering - this is handled in the application layer for better performance and cleaner separation of concerns.

## Output Structure

**Rows per site per day + 1 Grand Total row**:
1. **Grand Total** - Aggregates across ENTIRE date range and all sites (position 0)
2. Total (00-24) - Full day total per site per day
3. Overnight (00-05)
4. Breakfast (05-11)
5. Day (11-17)
6. Night (17-24)

**Output Structure (v4.1.0 - Story 3572)**:
- First row: Grand Total (`SortOrder = -1`, Date/SiteId/SiteName = NULL)
- Then per-day per-site breakdown with daily totals

**Examples**:
- Single site, 7-day range = 35 rows (1 site × 7 days × 5 rows per day)
- 3 sites, 7-day range = 105 rows (3 sites × 7 days × 5 rows per day)

## Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `Date` | DATE | Report date |
| `SiteName` | VARCHAR | Site display name |
| `DayPartLabel` | VARCHAR | Day part name (e.g., "Breakfast (05-11)") |
| `Value` | DECIMAL(18,2) | Main metric (depends on @SelectedView) |
| `PercentTotal` | DECIMAL(18,2) | % of that site's daily total (0 for Average view) |
| `PercentInc` | DECIMAL(18,2) | % change vs previous year |
| `SortOrder` | INT | Sort order (0 = Total, 1-4 = day parts) |

## Example Output

**@SiteId = NULL (All Sites), @SelectedView = 'D' (Dollar Sales), @ActiveOnly = 1**

| Date | SiteName | DayPartLabel | Value | PercentTotal | PercentInc | SortOrder |
|------|----------|-------------|--------|--------------|------------|-----------|
| 2025-12-01 | Auckland Central | Total (00-24) | 18296.15 | 100.00 | 5.23 | 0 |
| 2025-12-01 | Auckland Central | Overnight (00-05) | 535.24 | 2.93 | -2.45 | 1 |
| 2025-12-01 | Auckland Central | Breakfast (05-11) | 4250.30 | 23.24 | 3.12 | 2 |
| 2025-12-01 | Auckland Central | Day (11-17) | 7890.45 | 43.14 | 8.76 | 3 |
| 2025-12-01 | Auckland Central | Night (17-24) | 5620.16 | 30.72 | 4.89 | 4 |
| 2025-12-01 | Wellington CBD | Total (00-24) | 15420.80 | 100.00 | 8.12 | 0 |
| 2025-12-01 | Wellington CBD | Overnight (00-05) | 412.60 | 2.68 | -1.23 | 1 |
| ... | ... | ... | ... | ... | ... | ... |

## Data Sources

**Primary Tables**:
- `{SalesFact}` - Transaction data
- `{Site}` - Site master data (joined on `Site.Id = SalesFact.SiteId`)

**Filters Applied**:
- **Site Filter**: `SiteId IN (SELECT SiteId FROM SiteList)` - where SiteList is parsed from @SiteIds
- **Tenant Filtering**: Handled by OutSystems application layer (not in SQL)
- **Active Filtering**: Handled by OutSystems application layer (not in SQL)
- `CalendarDate BETWEEN @StartDate AND @EndDate`
- `DatePeriodDimensionId = 15` (15-minute intervals)
- `ProductSaleTypeId = 1` (product sales only)
- `ProductMenuId IS NULL`
- `TenderTypeId IS NULL`
- `OperationId IS NULL`
- `OperationKindId IS NULL`
- `SWCCashDrawerId IS NULL`
- `SaleTypeId IS NULL`
- `Pod = ''` (aggregate level)
- `PosId = 0` (aggregate level)

## Key Features

### 1. Timezone Conversion
- Database stores DateTime in UTC
- Converted to NZ timezone using `AT TIME ZONE 'New Zealand Standard Time'`
- Automatically handles NZDT (UTC+13) and NZST (UTC+12) based on DST

### 2. Multi-Site Support via @SiteIds
- Accepts comma-separated list of Site IDs (e.g., '3187,3188,3189')
- OutSystems pre-filters sites based on tenant and active/inactive status
- ⚠️ **CRITICAL**: Set `Expand Inline = YES` for SiteIds parameter!
- OutSystems injects values directly into SQL: `WHERE Id IN (3187,3188,3189)`
- No SQL parsing needed (no STRING_SPLIT, no XML, no CTEs)
- Site names from `Site.DisplayName` column
- **Cleaner separation**: Application layer handles filtering, SQL handles aggregation

### 3. Scaffold Pattern
- Guarantees all date/day-part/site combinations exist in output
- Missing data shows as 0 (not NULL)
- Prevents UI grid errors from missing rows

### 4. Single-Scan Optimization (v4.0.0)
- 🔥 **Single SalesFact read** for both CY and PY data (was 2 scans)
- Pre-calculates NZ timezone conversion BEFORE aggregation
- Uses YearType flag ('CY'/'PY') to classify rows in single pass
- Conditional aggregation with `CASE WHEN YearType = 'CY' THEN ...`
- **Result**: ~0.6 second performance for typical queries

### 5. Year-over-Year Comparison
- Previous Year = Current Year - 364 days (52 weeks)
- Ensures same day-of-week comparison (e.g., Monday to Monday)

### 6. View Switching
- Single query handles 3 different metrics via @SelectedView
- 'D' = Dollar Sales (NetAmount)
- 'G' = Guest Count (TransactionCount)
- 'A' = Average Check (NetAmount / TransactionCount)

### 7. Percent Calculations
- `PercentTotal` calculated per site (not across all sites)
- Each site's day parts sum to 100% of that site's daily total
- Window function partitioned by `ReportDate, SiteId`

## Performance Considerations

**Query Optimizations**:
1. **SiteList CTE**: Parses comma-separated @SiteIds using STRING_SPLIT() - single parse operation
2. **IN Clause**: Fast site filtering with `SiteId IN (SELECT SiteId FROM SiteList)`
3. **Early Filtering**: All WHERE conditions applied before aggregation
4. **Index Pushdown**: Filters designed to leverage existing indexes
5. **Separate CY/PY CTEs**: Cleaner execution plans
6. **Window Functions**: PercentTotal calculated without extra joins (partitioned by site)
7. **Numbers CTE**: Avoids recursion limit for large date ranges (supports 10,000 days)
8. **Application-Layer Filtering**: OutSystems handles tenant/active filtering (faster than SQL logic)

**Expected Performance**:
- Single site, 7-day range: < 1 second
- Single site, 30-day range: 1-2 seconds
- Single site, 90-day range: 3-5 seconds
- Multi-site (10 sites), 7-day range: 1-3 seconds
- Multi-site (50 sites), 7-day range: 3-8 seconds

## Index Recommendations

**Status**: To be reviewed after testing

Recommended indexes:
1. **IX_SalesFact_SiteId_CalendarDate_Filtered** (SiteId, CalendarDate)
   - INCLUDE: DateTime, NetAmount, TransactionCount
   - WHERE: DatePeriodDimensionId = 15 AND ProductSaleTypeId = 1
   - Impact: High
   - Status: To be evaluated

## Usage Examples

```sql
-- Example 1: Multiple sites, week of December 1-7, 2025 (Dollar Sales)
-- OutSystems passes pre-filtered list of active tenant sites
DECLARE @SiteIds NVARCHAR(MAX) = '3187,3188,3189';  -- Comma-separated list
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';
DECLARE @SelectedView VARCHAR(1) = 'D';

-- Output: 105 rows (3 sites × 7 days × 5 rows per day)
```

```sql
-- Example 2: Single site, month of December 2025 (Guest Count)
DECLARE @SiteIds NVARCHAR(MAX) = '3187';  -- Single site
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-31';
DECLARE @SelectedView VARCHAR(1) = 'G';

-- Output: 155 rows (1 site × 31 days × 5 rows per day)
```

## OutSystems Setup

**Advanced SQL Block**:
1. Create Input Parameters:
   - `SiteIds` (Text) - ⚠️ **Expand Inline: YES** ⚠️ - Comma-separated list
   - `StartDate` (Date) - Expand Inline: **No**
   - `EndDate` (Date) - Expand Inline: **No**
   - `SelectedView` (Text) - Expand Inline: **No**

2. **Application Layer Logic** (Before calling SQL):
   - Get current user's tenant
   - Filter sites based on tenant + active status
   - Build comma-separated list (e.g., "3187,3188,3189")
   - Pass to `SiteIds` parameter

3. Remove DECLARE statements from query (lines 43-46)

4. Query starts with `WITH` clause

**Example OutSystems Logic**:
```
// Get user's tenant sites (active only)
GetActiveSitesForTenant(UserId) → List<Site>

// Convert to comma-separated string
SiteIds = String.Join(",", SiteList.Select(s => s.Id.ToString()))

// Pass to SQL
AdvancedSQL.ProductSalesByDayPart(
    SiteIds: SiteIds,
    StartDate: StartDate,
    EndDate: EndDate,
    SelectedView: "D"
)
```

## Known Issues

- None identified yet (query in development)

## Related Queries

- **Child Query**: `queries/reports/product-sales-by-day-part-hourly/` - Hourly drill-down for single day
- **Similar**: `queries/reports/product-sales-by-pos-type-hourly/` - Hourly breakdown by Pod

## Testing

See `tests/` folder for diagnostic queries.

## Change Log

| Date | Version | Change | Author |
|------|---------|--------|--------|
| 2025-12-18 | v1.0.0 | Initial creation - parent query setup | Claude |
| 2025-12-18 | v2.0.0 | Multi-site support with SQL filtering | Claude |
| 2025-12-18 | v3.0.0 | Refactored to @SiteIds approach | Claude |
| 2025-12-18 | v4.0.0 | **Major optimization**: Expand Inline = YES for SiteIds, single-scan optimization | Claude |
| 2025-12-22 | v4.1.0 | **Story 3572**: Added Grand Total row at position 0 (aggregates entire dataset) | Claude |
