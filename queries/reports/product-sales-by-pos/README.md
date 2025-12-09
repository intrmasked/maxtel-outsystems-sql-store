# Query: Product Sales By POS Type (Date Range)

**Category**: Reports
**Created**: 2025-12-09
**Status**: Complete

---

## Purpose

Daily sales breakdown by Pod (Counter, Drive-Thru, Kiosk, Delivery) with year-over-year comparison. Supports date range filtering and multiple view modes.

---

## Input Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `@SiteId` | BIGINT | Yes | 3187 | Site identifier |
| `@StartDate` | DATE | Yes | - | Start date of range (inclusive) |
| `@EndDate` | DATE | Yes | - | End date of range (inclusive) |
| `@SelectedView` | VARCHAR(1) | Yes | 'D' | View mode: 'D' = Sales (NetAmount), 'G' = Guest Count, 'A' = Average Check |

---

## Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `Date` | DATE | Report date |
| `Pod` | VARCHAR | POD code (Total, CSO, DT, FC) |
| `Value` | DECIMAL | Main metric based on SelectedView |
| `PercentTotal` | DECIMAL | Percentage of daily total |
| `PercentInc` | DECIMAL | Year-over-year growth percentage |
| `SortOrder` | INT | Sort order (0 = Total, 1,2,3... = PODs alphabetically) |

---

## Tables Used

1. **SalesFact** - Sales transaction data
   - Reference: `database-context/tables/SalesFact/README.md`

---

## Query Logic

1. Generate complete date range using recursive CTE
2. Build scaffold with hardcoded PODs (FC, DT, CSO, DELIVERY) for performance
3. Fetch current year data (CY) from SalesFact
4. Fetch previous year data (PY) from SalesFact (364 days earlier)
5. Merge scaffold with raw data (ensures 0 values appear)
6. Calculate daily totals for "Total" row
7. Combine individual pod rows with total rows
8. Add sequential SortOrder matching get-pods-by-date-range
9. Calculate final metrics based on SelectedView
10. Filter out future dates (up to NZ current date)

**Key Optimizations:**
- Hardcoded pod list (no DISTINCT scan)
- Early filtering with index pushdown
- Window functions for percentage calculations
- Consistent pod ordering across all reports

---

## Performance

**Expected Execution Time**: < 500ms for 7-day range
**Optimization**: Index-friendly filtering, hardcoded pods, minimal scans

### Index Recommendations

**Status**: Recommended (Pending DBA review)

#### 1. IX_SalesFact_SiteId_CalendarDate_Filters_Includes
```sql
CREATE NONCLUSTERED INDEX IX_SalesFact_SiteId_CalendarDate_Filters_Includes
ON dbo.SalesFact (SiteId, CalendarDate, DatePeriodDimensionId, ProductSaleTypeId)
INCLUDE (Pod, NetAmount, TransactionCount, ProductMenuId, TenderTypeId,
         OperationId, OperationKindId, SWCCashDrawerId, SaleTypeId, PosId)
WITH (ONLINE = ON, FILLFACTOR = 90);
```
- **Impact**: High
- **Reason**: Covers all WHERE clause filters for CY and PY queries
- **Status**: Recommended

---

## Usage Example

### OutSystems Advanced SQL

```sql
-- Remove DECLARE statements
-- Add Input Parameters in OutSystems:
-- - SiteId (Long Integer, Expand Inline = No)
-- - StartDate (Date, Expand Inline = No)
-- - EndDate (Date, Expand Inline = No)
-- - SelectedView (Text, Expand Inline = No)

-- [Full query here - see query.sql]
```

### Sample Input
```
SiteId: 3187
StartDate: 2025-12-01
EndDate: 2025-12-07
SelectedView: 'D'
```

### Sample Output
```
Date       | Pod      | Value    | PercentTotal | PercentInc | SortOrder
-----------|----------|----------|--------------|------------|----------
2025-12-01 | Total    | 10000.00 | 0.00         | 5.50       | 0
2025-12-01 | CSO      | 2500.00  | 25.00        | 7.20       | 1
2025-12-01 | DELIVERY | 500.00   | 5.00         | 3.50       | 2
2025-12-01 | DT       | 4500.00  | 45.00        | 4.80       | 3
2025-12-01 | FC       | 2500.00  | 25.00        | 6.10       | 4
2025-12-02 | Total    | 11000.00 | 0.00         | 8.20       | 0
2025-12-02 | CSO      | 2700.00  | 24.55        | 6.50       | 1
...
```

---

## Notes

- POD ordering matches get-pods-by-date-range for consistency
- Total row always appears first (SortOrder = 0)
- PODs sorted alphabetically (CSO, DT, FC)
- Filters out dates beyond NZ current date
- Recursive CTE limited to 1000 iterations (max ~3 years)
- Hardcoded pods (FC, DT, CSO, DELIVERY) for performance
- YoY comparison uses 364-day offset

---

## Related Queries

- `queries/reports/product-sales-by-pos-type-hourly/` - Hourly breakdown
- `queries/utilities/get-pods-by-date-range/` - POD list utility
