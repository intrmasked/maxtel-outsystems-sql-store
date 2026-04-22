# 1.7 Raw Waste — Technical Design

**Source:** Daniel Reddington (2026-04-09)
**PRD:** Raw Waste

---

## Data Model

```
StockPeriod ──has──► RawWasteCount ◄──has── LogicalItem
                          │                     │
                          │              DefaultPhysicalItemId
                          │                     │
                     DayParts              PhysicalItem
                                                │
                                     LogicalItemSiteConfig
```

### RawWasteCount
| Column | Type | Description |
|--------|------|-------------|
| Id | Long Integer | PK |
| StockPeriodId | Long Integer | FK → StockPeriod |
| LogicalItemId | Long Integer | FK → LogicalItem |
| DayPartsId | Long Integer | FK → DayParts |
| WasteQty | Integer | Waste quantity in units |
| CostPerUnit | Decimal | Unit cost at creation time |
| LastUpdatedAt | Text | Timestamp of last update |

One row per LogicalItem × StockPeriod × DayPart. CostPerUnit set once on creation, never updated.

### Related Tables
- **StockPeriod** — SiteId, Date, StockPeriodStatusId
- **LogicalItem** — BO_RawItemId, ConceptId, WrinNumber, ItemName, DefaultPhysicalItemId
- **DayParts** — ConceptId, Order, Label, StartTime, EndTime
- **PhysicalItem** — ConceptId, WrinNumber, UnitsInCarton, UnitName
- **LogicalItemSiteConfig** — LogicalItemId, SiteId, IsWasteable, IsActive
- **StockPeriodBalance** — LogicalItemId, StockPeriodId, RawWasteQty, TheoClosedQty

Full table docs: `database-context/tables/[table-name]/README.md`

---

## Key Logic

### §1. Opening a date — GetOrCreate RawWasteCount rows

**Trigger:** User opens any date in Raw Waste UI (browse drill-down or entry slideout)
**Input:** SiteId, Date
**Status:** COMPLETE (Story 3758)

1. Call `GetOrCreateStockPeriod(SiteId, Date)` → StockPeriodId
2. Query RawWasteCount WHERE StockPeriodId = StockPeriodId
3. If rows exist → skip creation, proceed to display
4. If no rows:
   - Fetch wasteable LogicalItems (IsActive = true AND IsWasteable = true for SiteId)
   - Fetch all DayParts for site's ConceptId
   - For each LogicalItem × DayPart:
     - Resolve PhysicalItem via LogicalItem.DefaultPhysicalItemId
     - Find most recent BO_RawItemPrice (ConceptId + WRIN, ORDER BY Effective DESC, TOP 1)
     - CostPerUnit = BO_RawItemPrice.Value / PhysicalItem.UnitsInCarton
     - Insert RawWasteCount(StockPeriodId, LogicalItemId, DayPartsId, WasteQty = 0, CostPerUnit)

**Output:** RawWasteCount rows exist for all wasteable items × all shifts

---

### §2. Saving a waste entry — Update RawWasteCount

**Trigger:** User saves entry slideout (non-Stock Count sites only)
**Input:** StockPeriodId, DayPartsId, list of { LogicalItemId, WasteQty }
**Status:** COMPLETE (Story 3746)

1. For each item in the list:
   - UPDATE RawWasteCount SET WasteQty, LastUpdatedAt = now()
     WHERE StockPeriodId AND LogicalItemId AND DayPartsId
2. Call UpdateStockPeriodBalance (§3) for each affected LogicalItemId

**Output:** RawWasteCount rows updated; StockPeriodBalance kept in sync

---

### §3. Updating StockPeriodBalance after waste change

**Trigger:** After any write to RawWasteCount (from Raw Waste UI or Stock Count sync §4)
**Input:** StockPeriodId, LogicalItemId
**Status:** COMPLETE (Story 3746)

1. GetOrCreate StockPeriodBalance WHERE StockPeriodId AND LogicalItemId
2. Calculate RawWasteQty:
   ```
   RawWasteQty = SUM(RawWasteCount.WasteQty × PhysicalItem.PortionsPerUnit)
     WHERE StockPeriodId = StockPeriodId AND LogicalItemId = LogicalItemId
     (sum across all DayParts; PhysicalItem via LogicalItem.DefaultPhysicalItemId)
   ```
3. Call UpdateStockPeriodBalanceTotals to recalculate TheoClosedQty

**Output:** StockPeriodBalance.RawWasteQty and TheoClosedQty are current

---

### §4. Stock Count sync — LocationCountItem → RawWasteCount

**Trigger:** LocationCountItem change for Stock Count sites
**Input:** LocationCountItem change event (SiteId, Date, LocationId, CentralStockItemId)
**Status:** NOT STARTED

1. Resolve LogicalItemId:
   - JOIN CentralStockItem ON CentralStockItemId
   - JOIN LogicalItem ON WrinNumber = CentralStockItem.WrinNumberClean AND ConceptId matches
2. Resolve DayPartsId:
   - JOIN Location ON LocationId
   - JOIN DayParts ON Label = Location.Name AND ConceptId = site's ConceptId
3. Resolve StockPeriodId via GetOrCreateStockPeriod(SiteId, Date)
4. Ensure RawWasteCount row exists (run GetOrCreate §1 if needed)
5. UPDATE RawWasteCount SET WasteQty = LocationCountItem.UnitValue, LastUpdatedAt = now()
6. Call UpdateStockPeriodBalance (§3) for affected LogicalItemId

**Output:** RawWasteCount reflects latest Stock Count entry; StockPeriodBalance updated

---

### §5. Daily Waste Sheet report

**Trigger:** User requests Waste Form report from print slideout in Report_UI
**Input:** StartDate, EndDate, SiteId, MenuType (Breakfast | Regular | Both)
**Status:** NOT STARTED

**Report_CS:**
1. Query wasteable LogicalItems (filtered by SiteId, IsActive, IsWasteable, MenuType)
2. Resolve PhysicalItem via DefaultPhysicalItemId
3. Populate DailyWasteSheet structure:
   - WRIN = LogicalItem.WrinNumber
   - Menu = LogicalItem.ItemType
   - Description = LogicalItem.ItemName
   - UOM = PhysicalItem.UnitName
   - UnitCost = RawWasteCount.CostPerUnit (most recent for period)
4. If IsJSONOnly → return JSON
5. Otherwise → CreatePDFReportFromJSON → return binary

**Report_UI:**
- Filters: Start Date, End Date, Site, Menu Type (Breakfast / Regular / Both)
- No shift filter
- Standard report pattern (view in browser or download)

DailyWasteSheet structure is pre-existing. This story registers the report in SupportedReport and wires up the request/response cycle. Combit formatting is a separate story.

---

## Integration Points

| Direction | System / Event | Detail |
|-----------|---------------|--------|
| Inbound | Stock Count app — LocationCountItem change | Triggers sync (§4) to write waste into RawWasteCount |
| Internal | UpdateStockPeriodBalanceRawWaste (existing — **modified**) | Must read from RawWasteCount instead of LocationCountItem. Calculates RawWasteQty = SUM(WasteQty × PortionsPerUnit) across all DayParts |
| Internal | UpdateStockPeriodBalanceTotals (existing) | Called after every RawWasteQty update to recalculate TheoClosedQty |
| Internal | GetOrCreateStockPeriod (existing) | Resolves or creates StockPeriod row |
| Outbound | Report_CS — DailyWasteSheet | New report in SupportedReport; JSON or PDF via CreatePDFReportFromJSON |

---

## Implementation Status

| Section | Story | Status |
|---------|-------|--------|
| §1 GetOrCreate RawWasteCount | 3758 | COMPLETE |
| §2 Save waste entry | 3746 | COMPLETE (backend) — UI pending |
| §3 UpdateStockPeriodBalance | 3746 | COMPLETE (backend) — testing pending |
| §4 Stock Count sync | TBD | NOT STARTED |
| §5 Daily Waste Sheet report | TBD | NOT STARTED |
