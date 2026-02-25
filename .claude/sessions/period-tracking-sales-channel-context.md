# Session: Period Tracking Sales Channel - 2026-02-25

## Original Story/Requirements

**User Request:**
```
PeriodTrackingReport will provide a total for the calendar date range selected
(business date for MOP and Delivery).
Same structure as DailyTrackingSalesChannel but for a date range.
```

**Additional Context:**
- Same 3 channels as DailyTrackingSalesChannel: MOP, Delivery, McCafe
- MOP and Delivery aggregate across BusDate BETWEEN StartDate AND EndDate
- McCafe aggregates across CalendarDate BETWEEN StartDate AND EndDate
- Output structure identical to daily version

---

## Status

- [/] In Development — query written and committed (WIP), pending sandbox verification

---

## Tables Used

Same as DailyTrackingSalesChannel — see `daily-tracking-sales-channel-context.md` for full table details.

| Table | Purpose |
|-------|---------|
| `SWCPeriod` | Get all OperatingPeriodIds in the BusDate range |
| `SWCPeriodTender` | MOP and Delivery CountedAmount + Transactions |
| `TenderType` | Filter Name='MOP' and IsDelivery=1 |
| `SalesFact2` | McCafe NetAmount + Transactions (Report_CS alias) |
| `ProductMenu` | Bridge to BO_MenuItem |
| `BO_MenuItem` | IsMcCafe flag |

---

## Query Location

```
queries/utilities/period-tracking-sales-channel/
├── query.sql               ← Production query (no DECLAREs, {SalesFact2} for McCafe)
├── output-structure.json   ← { Label, NetSales, Transactions, IsCalendarDay }
├── metadata.json
├── README.md
└── tests/
    ├── test-ssms.sql           ← Full query with DECLAREs ({SalesFact} for sandbox)
    ├── test-mop.sql            ← Per-day MOP rows across date range
    ├── test-delivery.sql       ← Per-day Delivery rows by tender type
    ├── test-mccafe.sql         ← Per-product, per-day McCafe rows + dim checks
    └── test-find-valid-dates.sql ← Finds weeks where all 3 channels non-zero
```

---

## Key Differences from DailyTrackingSalesChannel

| | Daily | Period |
|-|-------|--------|
| Date params | `Date` (single) | `StartDate` + `EndDate` (range) |
| Period CTE | `TargetPeriod` (single row) | `TargetPeriods` (all periods in range) |
| MOP/Delivery filter | `BusDate = @Date` | `BusDate BETWEEN @StartDate AND @EndDate` |
| McCafe filter | `CalendarDate = @Date` | `CalendarDate BETWEEN @StartDate AND @EndDate` |
| test-find-valid-dates | Groups by day | Groups by week |

---

## Open Questions / For Next Session

- Sandbox verification — run `test-find-valid-dates.sql` to find a valid week, then `test-ssms.sql`
- Confirm totals match expected values from the report UI

---

## Commits This Session

| Hash | Description |
|------|-------------|
| `b18abfc` | feat: Add PeriodTrackingSalesChannel utility query (WIP) |
