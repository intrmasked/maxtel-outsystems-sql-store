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
2. Fetch CY and PY data using UNION ALL (forces parallel index seeks)
3. Aggregate combined data points (CY + PY in single aggregation)
4. Derive active PODs from aggregated data (only pods with CY activity)
5. Build grid (Dates × Active PODs with LEFT JOIN to aggregated data)
6. Calculate totals and sorting (window functions + Total row via UNION ALL)
7. Final metrics calculation based on SelectedView
8. Filter out future dates (up to NZ current date)

**Key Optimizations:**
- **UNION ALL approach**: Forces SQL Server to run CY and PY queries in parallel with direct index seeks
- **Pre-aggregation**: Aggregates raw data before building scaffold (reduces data volume)
- **RECOMPILE hint**: Forces query recompilation for optimal execution plan each run
- **Window functions**: Calculates daily totals without extra joins
- **Dynamic pod detection**: Only pods with CY activity appear (no hardcoded lists)
- **Performance**: 16s → 1s for 30-day range (16x faster)

---

## Performance

**Measured Execution Time**:
- 7-day range: < 500ms
- 30-day range: ~1s (tested)
- 90-day range: ~2-3s (estimated)

**Optimization Strategy**:
- UNION ALL forces parallel index seeks on CY and PY date ranges
- Pre-aggregation reduces data volume before scaffold building
- RECOMPILE ensures optimal execution plan for parameter variations
- Window functions eliminate extra joins for daily totals

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
- PODs sorted alphabetically (CSO, DELIVERY, DT, FC)
- Filters out dates beyond NZ current date
- Recursive CTE limited to 1000 iterations (max ~3 years)
- Dynamic pod detection from aggregated data (only pods with CY activity)
- UNION ALL approach for parallel execution (CY + PY queries run simultaneously)
- RECOMPILE hint ensures optimal execution plan for each parameter set
- YoY comparison uses 364-day offset
- Performance: 16x faster than previous version (16s → 1s for 30 days)

---

## Related Queries

- `queries/reports/product-sales-by-pos-type-hourly/` - Hourly breakdown
- `queries/utilities/get-pods-by-date-range/` - POD list utility
