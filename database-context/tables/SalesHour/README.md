# Table: SalesHour

**OutSystems Entity**: SalesHour
**Module**: Sales_CS
**Database Table**: [dbo].[SalesHour]
**Purpose**: Stores hourly sales projections and actuals for each site — used for projected vs actual sales comparisons
**Last Updated**: 2026-03-15

---

## Overview

`SalesHour` holds hourly sales data per site, including suggested/projected/actual amounts and transaction counts. Each row represents one hour for a site on a given date (via `StartDateTime`). Used to calculate projected product sales based on hourly ratios.

---

## Table Structure

### Key Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `Id` | Long Integer | Primary key, auto-increment |
| `StartDateTime` | Date Time | Hour start timestamp (e.g., 2026-03-15 04:00:00) |
| `SiteId` | Long Integer | FK to Site |
| `RestaurantZoneId` | Long Integer | Restaurant zone reference |

### Suggested Values

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `SuggestedSalesIncGST` | Decimal | Suggested sales including GST |
| `SuggestedSalesExclGST` | Decimal | Suggested sales excluding GST |
| `SuggestedTransactions` | Decimal | Suggested transaction count |

### Actual Values

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `ActualSalesIncGST` | Decimal | Actual sales including GST |
| `ActualSalesExclGST` | Decimal | Actual sales excluding GST |
| `ActualTransactions` | Decimal | Actual transaction count |

### Projected Values

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `ProjectedSalesExclGST` | Decimal | Projected sales excluding GST |
| `ProjectedSalesIncGST` | Decimal | Projected sales including GST |
| `ProjectedTransactions` | Decimal | Projected transaction count |

### Other Columns

| Column Name | Data Type | Description |
|-------------|-----------|-------------|
| `NP6ActualSalesAreImported` | Boolean | NP6 actual sales import flag |
| `LastUpdatedAt` | Date Time | Last update timestamp |
| `ProjectedSalesOnPub` | Decimal | Projected sales on pub |
| `ProjectedTransactionsOnPub` | Decimal | Projected transactions on pub |

---

## Relationships

### How to Join to SalesFact

`SalesHour` links to `SalesFact` via hour and site matching:

```sql
-- Join on SiteId + hour of StartDateTime matching hour of SalesFact.DateTime
LEFT JOIN {SalesHour} sh
    ON sh.SiteId = @SiteId
    AND DATEPART(hour, sh.StartDateTime) = DATEPART(hour, sf.DateTime)
    AND CAST(sh.StartDateTime AS DATE) = CAST(sf.DateTime AS DATE)
```

---

## Common Query Patterns

### Get Projected Sales for a Date
```sql
SELECT
    StartDateTime,
    ProjectedSalesExclGST,
    ProjectedTransactions
FROM {SalesHour}
WHERE SiteId = @SiteId
    AND CAST(StartDateTime AS DATE) = @BusDate
ORDER BY StartDateTime
```

---

## Notes for OutSystems

- **Module**: `Sales_CS`
- **StartDateTime** = Hour start time; use `DATEPART(hour, StartDateTime)` to match hours
- **ProjectedSalesExclGST** = Primary field for projected sales calculations
- **One row per hour per site** — 24 rows per trading day
- **Expose Read Only**: No (read-write entity)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-15 | Initial documentation created from OutSystems entity screenshot | Claude |
