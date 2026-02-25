# Session: Daily Tracking Sales Channel - 2026-02-24

## Original Story/Requirements

**User Request:**
```
Create two new SQL queries for the DailyTrackingReport:
1. DailyTrackingSalesChannel (utility) - Returns 3 Sales Channel rows for a selected business date and site
2. PeriodTrackingSalesChannel (utility) - Returns totals for a selected date range (TBD)

Sales Channels:
- MOP      → SWCPeriodTender where TenderType.Name = 'MOP'
- Delivery → SWCPeriodTender where TenderType.IsDelivery = 1
- McCafe   → SalesFact2 (Report_CS) joined via SWCPeriod + ProductMenu + BO_MenuItem where IsMcCafe = 1

Output must match SalesChannelList structure:
- Label (Text)
- NetSales (Decimal)
- Transactions (Integer)
- IsCalendarDay (Boolean) — 0 = BusDate (MOP/Delivery), 1 = CalendarDate (McCafe)
```

**Additional Context:**
- MOP and Delivery use CountedAmount (Gross) — no tax needed
- McCafe uses NetAmount (Net) — no tax needed
- MOP and Delivery filter by Business Date via SWCPeriod
- McCafe filters by Calendar Date via SalesFact2.CalendarDate
- IsCalendarDay flag tells OutSystems which date type sourced each row
- TenderType.IsDelivery = 1 for: MOP, DoorDash, UberEats, DeliverEasy (already set in DB)

---

## Status

- [/] In Development — `DailyTrackingSalesChannel` complete, pending sandbox verification
- [ ] `PeriodTrackingSalesChannel` not yet started

**Current step**: Query written and committed (WIP). Pending live sandbox test with valid date from `test-find-valid-dates.sql`.

---

## Tables Used

| Table | Purpose | Module |
|-------|---------|--------|
| `SWCPeriod` | Get OperatingPeriodId by SiteId + BusDate | Sales_CS |
| `SWCPeriodTender` | MOP and Delivery CountedAmount + Transactions | Sales_CS |
| `TenderType` | Filter by Name='MOP' and IsDelivery=1 | Sales_CS |
| `SalesFact2` | McCafe NetAmount + Transactions (Report_CS alias) | Report_CS |
| `SWCPeriod` | SiteId filter for SalesFact2 join | Sales_CS |
| `ProductMenu` | Bridge SalesFact2 to BO_MenuItem | Sales_CS |
| `BO_MenuItem` | IsMcCafe flag, joined on MIN + ConceptId | People_CS |

---

## Query Location

```
queries/utilities/daily-tracking-sales-channel/
├── query.sql               ← Production query (no DECLAREs)
├── output-structure.json   ← { Label, NetSales, Transactions, IsCalendarDay }
├── metadata.json
├── README.md
└── tests/
    ├── test-ssms.sql           ← Full query with DECLAREs for sandbox
    ├── test-mop.sql            ← Verify MOP rows from SWCPeriodTender
    ├── test-delivery.sql       ← Verify Delivery rows by tender type
    ├── test-mccafe.sql         ← Verify McCafe rows per product with dim checks
    └── test-find-valid-dates.sql ← Find dates where MOP + Delivery + McCafe are all non-zero
```

---

## Key Design Decisions

### MOP Filter
- Filter using `TenderType.Name = 'MOP'` — **not** `IsMobileEFTPos = 1`
- Reason: Name-based filter is more reliable across tenants

### Delivery Filter
- Filter using `TenderType.IsDelivery = 1`
- Covers: MOP, DoorDash, UberEats, DeliverEasy (all have IsDelivery = 1)
- MOP is a subset of Delivery — both are separate output rows

### McCafe Join Pattern
```sql
FROM {SalesFact2} sf2          -- Report_CS alias (one-off — all others use {SalesFact})
INNER JOIN {SWCPeriod} sp  ON sf2.SWCPeriodId  = sp.Id
LEFT JOIN  {ProductMenu} pm ON sf2.ProductMenuId = pm.Id
LEFT JOIN  {BO_MenuItem} mi ON pm.ProductId      = mi.MIN
                            AND pm.ConceptId      = mi.ConceptId
WHERE sp.SiteId = @SiteId
  AND sf2.CalendarDate = @Date
  AND mi.IsMcCafe = 1
  -- Plus all standard SalesFact dimension NULL filters
```
- ConceptId matched naturally via ProductMenu — no input param needed
- Uses `{SalesFact2}` in query.sql because this runs in Report_CS module context

### No TaxAmount
- SWCPeriodTender has no TaxAmount column — agreed to drop it entirely
- McCafe: NetAmount is used, no tax field needed

### IsCalendarDay Flag
- `CAST(0 AS BIT)` for MOP and Delivery (BusDate sources)
- `CAST(1 AS BIT)` for McCafe (CalendarDate source)
- Allows OutSystems server action to handle mapping correctly

---

## DB Context Updates This Session

| File | Status |
|------|--------|
| `database-context/tables/TenderType/README.md` | Updated — new columns: IsDelivery, IsHoldingCash, IsMobileEFTPos, Order, ConceptId, LegacyId, IsPhysicalTender, IsIncludedInSWCTotals, IsCashEquivilent |
| `database-context/tables/BO_MenuItem/README.md` | New — documented from OutSystems entity screenshots (People_CS module) |

---

## claude.md Updates This Session

- `output-structure.json` added as required file for all new queries (2026-02-24+)
- `test-ssms.sql` added as required test file
- Folder structure template updated
- OutSystems Handover section updated: output-structure.json format is plain JSON object `{ ColumnName: OutSystemsType }`
- Old queries exempted from new rules

---

## Open Questions / For Next Session

1. **Sandbox verification** — Run `test-find-valid-dates.sql` to find a date where all 3 channels are non-zero, then run `test-ssms.sql` to verify totals match expected values
2. **PeriodTrackingSalesChannel** — Period-range version of this query (TBD)
3. **SWCPeriodTender DB context** — Table has no README yet; document it once structure confirmed via sandbox

---

## Commits This Session

| Hash | Description |
|------|-------------|
| `bcffb39` | feat: Add DailyTrackingSalesChannel utility query (WIP) + DB context updates |
| `c36d073` | fix(daily-tracking-sales-channel): Refine output columns, join pattern, and SalesFact2 alias (WIP) |
