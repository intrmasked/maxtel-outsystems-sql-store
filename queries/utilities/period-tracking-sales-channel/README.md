# Query: PeriodTrackingSalesChannel

**Location**: `queries/utilities/period-tracking-sales-channel/query.sql`
**Category**: Utilities
**Created**: 2026-02-25
**Status**: In Testing
**Version**: 1.0.0

---

## Purpose

Returns **3 Sales Channel rows** aggregated over a selected date range, for `PeriodTrackingReport.SalesChannels`:

| Row | Channel | Source | Date Filter |
|-----|---------|--------|-------------|
| 1 | MOP | `SWCPeriodTender` where `TenderType.Name = 'MOP'` | `BusDate BETWEEN StartDate AND EndDate` |
| 2 | Delivery | `SWCPeriodTender` where `TenderType.IsDelivery = 1` | `BusDate BETWEEN StartDate AND EndDate` |
| 3 | McCafe | `SalesFact2 → SWCPeriod → ProductMenu → BO_MenuItem` where `IsMcCafe = 1` | `CalendarDate BETWEEN StartDate AND EndDate` |

---

## Parameters (OutSystems)

| Parameter | Type | Expand Inline | Description |
|-----------|------|---------------|-------------|
| `SiteId`    | LongInteger | No | Site to query |
| `StartDate` | Date        | No | Start of date range (inclusive) |
| `EndDate`   | Date        | No | End of date range (inclusive) |

---

## Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `Label` | Text | Channel name: 'MOP', 'Delivery', 'McCafe' |
| `NetSales` | Decimal | Gross CountedAmount (MOP/Delivery) or Net NetAmount (McCafe) |
| `Transactions` | Integer | Total transaction/guest count across the date range |
| `IsCalendarDay` | Boolean | `false` = BusDate source (MOP/Delivery), `true` = CalendarDate source (McCafe) |

---

## Key Design Decisions

1. **Date range**: `BETWEEN @StartDate AND @EndDate` (inclusive) on both ends
2. **MOP/Delivery**: Use `BusDate` via `SWCPeriod` → `TargetPeriods` CTE — aggregates all periods in range
3. **McCafe**: Uses `CalendarDate` on `SalesFact2.CalendarDate` directly — same dimension filters as daily version
4. **{SalesFact2}**: This query runs in `Report_CS` — SalesFact is exposed as `SalesFact2` in that module (one-off, all other queries use `{SalesFact}`)
5. **CountedAmount vs NetAmount**: MOP/Delivery use Gross (`CountedAmount`), McCafe uses Net (`NetAmount`) — consistent with daily version
6. **No tax**: No TaxAmount anywhere — agreed, not needed for this output

---

## Relationship to DailyTrackingSalesChannel

This query is the period-range counterpart of `DailyTrackingSalesChannel`:

| | Daily | Period |
|-|-------|--------|
| Date param | `Date` (single day) | `StartDate` + `EndDate` (range) |
| MOP/Delivery CTE | `BusDate = @Date` | `BusDate BETWEEN @StartDate AND @EndDate` |
| McCafe CTE | `CalendarDate = @Date` | `CalendarDate BETWEEN @StartDate AND @EndDate` |
| Output shape | Same | Same |

---

## OutSystems Integration

### Output Structure (output-structure.json)
```json
{
    "Label":         "Text",
    "NetSales":      "Decimal",
    "Transactions":  "Integer",
    "IsCalendarDay": "Boolean"
}
```

### Parameters Setup
| Name | Data Type | Expand Inline |
|------|-----------|---------------|
| SiteId | Long Integer | No |
| StartDate | Date | No |
| EndDate | Date | No |
