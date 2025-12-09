# Query: Get Available PODs for Date Range

**Category**: Utilities
**Created**: 2025-12-09
**Status**: Complete

---

## Purpose

Retrieve distinct POD (Point of Delivery) values that had activity within a specified date range. Optimized for maximum performance.

---

## Input Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `@SiteId` | BIGINT | Yes | 3187 | Site identifier |
| `@StartDate` | DATE | Yes | - | Start date of range (inclusive) |
| `@EndDate` | DATE | Yes | - | End date of range (inclusive) |

---

## Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `podid` | VARCHAR | POD code (FC, DT, CSO, DELIVERY, etc.) or "Total" |
| `podname` | VARCHAR | POD display name (Counter, Drive-Thru, Kiosk, etc.) or "Total" |
| `SortOrder` | INT | Sequential sort order (0 = Total, 1,2,3... = PODs alphabetically) |

---

## Tables Used

1. **SalesFact** - Source of POD values and sales activity
   - Reference: `database-context/tables/SalesFact/README.md`

---

## Query Logic

1. Query SalesFact for distinct POD values in date range
2. Apply same filters as product-sales-by-pos-type-hourly:
   - DatePeriodDimensionId = 15
   - ProductSaleTypeId = 1 (Product Sales)
   - ProductMenuId IS NULL (Aggregated)
   - TenderTypeId IS NULL (Aggregated)
   - OperationId IS NULL (Aggregated)
   - OperationKindId IS NULL (Aggregated)
   - SWCCashDrawerId IS NULL (Aggregated)
   - SaleTypeId IS NULL (Aggregated)
   - Pod IS NOT NULL AND Pod <> ''
3. Map POD codes to display names:
   - FC → Counter
   - DT → Drive-Thru
   - CSO → Kiosk
   - DELIVERY → Delivery
4. Add "Total" row at top (SortOrder = 0)
5. Assign sequential SortOrder to PODs (1, 2, 3, ...) alphabetically by Pod code
6. Return all rows sorted by SortOrder

---

## Performance

**Expected Execution Time**: < 100ms
**Optimization**: Minimal joins, early filtering, indexed columns

### Index Recommendations

**Status**: Recommended (Pending DBA review)

#### 1. IX_SalesFact_SiteId_CalendarDate_Includes
```sql
CREATE NONCLUSTERED INDEX IX_SalesFact_SiteId_CalendarDate_Includes
ON dbo.SalesFact (SiteId, CalendarDate)
INCLUDE (Pod)
WITH (ONLINE = ON, FILLFACTOR = 90);
```
- **Impact**: High
- **Reason**: Covers WHERE clause filters and SELECT column
- **Status**: Recommended
- **Expected Performance**: < 50ms with index

---

## Usage Example

### OutSystems Advanced SQL

```sql
-- Remove DECLARE statements
-- Add Input Parameters in OutSystems:
-- - SiteId (Long Integer, Expand Inline = No)
-- - StartDate (Date, Expand Inline = No)
-- - EndDate (Date, Expand Inline = No)

WITH ActivePods AS (
    SELECT DISTINCT sf.Pod
    FROM {SalesFact} sf
    WHERE sf.SiteId = @SiteId
        AND sf.CalendarDate BETWEEN @StartDate AND @EndDate
        AND sf.DatePeriodDimensionId = 15
        AND sf.Pod IS NOT NULL AND sf.Pod <> ''
        AND sf.ProductSaleTypeId = 1
        AND sf.ProductMenuId IS NULL
        AND sf.TenderTypeId IS NULL
        AND sf.OperationId IS NULL
        AND sf.OperationKindId IS NULL
        AND sf.SWCCashDrawerId IS NULL
        AND sf.SaleTypeId IS NULL
),

PodList AS (
    SELECT
        'Total' AS podid,
        'Total' AS podname,
        0 AS SortOrder
    UNION ALL
    SELECT
        Pod AS podid,
        CASE Pod
            WHEN 'FC' THEN 'Counter'
            WHEN 'DT' THEN 'Drive-Thru'
            WHEN 'CSO' THEN 'Kiosk'
            WHEN 'DELIVERY' THEN 'Delivery'
            ELSE Pod
        END AS podname,
        ROW_NUMBER() OVER (ORDER BY Pod) AS SortOrder
    FROM ActivePods
)

SELECT
    podid,
    podname,
    SortOrder
FROM PodList
ORDER BY SortOrder;
```

### Sample Input
```
SiteId: 3187
StartDate: 2025-12-01
EndDate: 2025-12-07
```

### Sample Output
```
podid      | podname      | SortOrder
-----------|--------------|----------
Total      | Total        | 0
CSO        | Kiosk        | 1
DELIVERY   | Delivery     | 2
DT         | Drive-Thru   | 3
FC         | Counter      | 4
```

---

## Notes

- Returns PODs with aggregated sales activity in date range
- Filters match product-sales-by-pos-type-hourly for consistency
- Includes "Total" row at top (SortOrder = 0)
- POD name mapping for user-friendly display
- Sequential SortOrder: 0 (Total), 1, 2, 3, ... (PODs alphabetically)
- Total always appears first
- Lightning fast with recommended indexes (< 50ms)
- Use in Server Actions for dropdown/list population

---

## DBA Request Template

```
Subject: Index Creation Request - MaxTel OutSystems SQL Store (Get PODs by Date Range)

Hi DBA Team,

We need the following index created for the "Get PODs by Date Range" query optimization:

1. IX_SalesFact_SiteId_CalendarDate_Includes
   - Table: dbo.SalesFact
   - Columns: (SiteId, CalendarDate) INCLUDE (Pod)
   - Purpose: Optimize POD lookup by date range
   - Expected Impact: Query time < 50ms

Environment: OutSystems Production Database
Impact: Read-only query, no schema changes
Priority: Medium

Please execute via SQL Server Management Studio (SSMS) as OutSystems cannot create indexes directly.

Thank you!
```
