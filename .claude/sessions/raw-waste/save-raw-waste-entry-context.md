# Session: Save Raw Waste Entry — 2026-04-22

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_boards/board/t/Scheduling%20Team/Stories?workitem=3746
**PRD:** See prd.md in this folder

---

## Original Story/Requirements

When a user saves waste quantities from the entry slideout:
1. Write the updated WasteQty values back to RawWasteCount for the selected date and shift
2. Modify the existing UpdateStockPeriodBalanceRawWaste action to read from RawWasteCount (instead of LocationCountItem) and calculate RawWasteQty as SUM(WasteQty × PhysicalItem.PortionsPerUnit) across all shifts
3. Call UpdateStockPeriodBalanceTotals to recalculate TheoClosedQty

---

## Status
- [ ] Complete / [ ] In Progress / [X] In Testing
- Current step: Backend complete. List screen built (query + UI + export). Detail screen SQL done, UI paused on category separators. Slideout not started yet.
- **Not using** existing `UpdateStockPeriodBalanceRawWaste` action — building fresh in SaveRawWasteEntry

---

## Design Decisions

### No Advanced SQL — Aggregates Only
- **Decision**: Entire story uses OutSystems Aggregates + Entity Actions. Zero Advanced SQL.
- **Rationale**: The calculations are simple (2-table JOIN, SUM with filter). Aggregates-first rule applies.

### Per-Item Calculation (not bulk UPDATE)
- **Decision**: Calculate RawWasteQty per LogicalItemId in a loop, update via entity action
- **Rationale**: Avoids writing a raw UPDATE SQL query. OutSystems entity actions handle the UPDATE. Simpler to maintain.

### Don't reuse existing StockLedger actions
- **Decision**: Not using `UpdateStockPeriodBalanceRawWaste` (existing action under StockLedger). Building the logic directly in SaveRawWasteEntry.
- **Rationale**: Existing actions are used for other flows (LocationCountItem-based) and don't fit this use case. Cleaner to build fresh.

### Two StockPeriodBalance updates per item
- **Decision**: First entity action sets `RawWasteQty`, then `UpdateStockPeriodBalanceTotals` recalculates `TheoClosedQty` (and `OpenQty`, `StartIsTheo`).
- **Rationale**: `UpdateStockPeriodBalanceTotals` needs the updated RawWasteQty already written to calculate correctly. Same pattern as Delivery/Transfer flows.

---

## Structure Created

### WasteEntryRecord
| Attribute | Type |
|-----------|------|
| `LogicalItemId` | Long Integer |
| `WasteQty` | Decimal |

---

## OutSystems Build — Final Flow

### Service Action: SaveRawWasteEntry (Public wrapper)
- Module: Stock_CS
- Public = Yes
- Calls private Server Action

### Server Action: SaveRawWasteEntry (Private)
- Module: Stock_CS
- Public = No

**Inputs:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `StockPeriodId` | Long Integer | Identifies the date + site |
| `DayPartsId` | Long Integer | Identifies the shift |
| `SiteId` | Long Integer | Site for StockPeriod lookups |
| `Date` | Date | Date for StockPeriod lookups |
| `WasteEntries` | Record List of WasteEntryRecord | Items + quantities |

**Flow:**

#### Step 1: Input Validation
- If `DayPartsId = NullIdentifier()` → Application Exception
- If `WasteEntries.Empty` → Application Exception

#### Step 2: Save RawWasteCount Rows (First For Each loop)
- Loop through WasteEntries
- For each entry:
  - **Aggregate (GetRawWasteCounts)**: Get existing RawWasteCount row
    - Filter: `RawWasteCount.StockPeriodId = StockPeriodId and RawWasteCount.LogicalItemId = WasteEntries.Current.LogicalItemId and RawWasteCount.DayPartsId = DayPartsId`
  - If not empty → **Entity Action (UpdateRawWasteCount)**: Set WasteQty + LastUpdatedAt

#### Step 3: Recalculate StockPeriodBalance (Second For Each loop)
- Loop through WasteEntries again
- For each entry:
  - **Aggregate (GetSumOfRawWaste)**: Calculate total waste in portions
    - Sources: RawWasteCount JOIN LogicalItem JOIN PhysicalItem
    - Filter: `RawWasteCount.StockPeriodId = StockPeriodId and RawWasteCount.LogicalItemId = WasteEntries.Current.LogicalItemId`
    - Output: `SUM(RawWasteCount.WasteQty × PhysicalItem.PortionsPerUnit)`
  - **Aggregate (StockPeriodBalance — current day)**: Fetch balance row
    - Sources: StockPeriodBalance JOIN StockPeriod
    - Filter: `StockPeriod.SiteId = SiteId and StockPeriod.Date = Date and StockPeriodBalance.LogicalItemId = WasteEntries.Current.LogicalItemId`
  - **Aggregate (StockPeriodBalance — previous day)**: Fetch prev day balance
    - Sources: StockPeriodBalance JOIN StockPeriod
    - Filter: `StockPeriod.SiteId = SiteId and StockPeriod.Date = AddDays(Date, -1) and StockPeriodBalance.LogicalItemId = WasteEntries.Current.LogicalItemId`
  - **Entity Action (UpdateStockPeriodBalance)**: Set `RawWasteQty = GetSumOfRawWaste.List.Current.Sum`
  - **Server Action (UpdateStockPeriodBalanceTotals)**: Pass current + prev day balance → recalculates TheoClosedQty, OpenQty, StartIsTheo

---

## Tables Used
- `RawWasteCount` — EXISTING — update WasteQty per shift
- `StockPeriodBalance` — EXISTING — update RawWasteQty (in portions), then recalculate TheoClosedQty
- `StockPeriod` — EXISTING — join for SiteId + Date lookups
- `LogicalItem` — EXISTING — join to get DefaultPhysicalItemId
- `PhysicalItem` — EXISTING — PortionsPerUnit for unit→portion conversion

## Queries Created
- None — all Aggregates + Entity Actions

---

## Key Formula
```
StockPeriodBalance.RawWasteQty = SUM(RawWasteCount.WasteQty × PhysicalItem.PortionsPerUnit)
  WHERE StockPeriodId = @StockPeriodId AND LogicalItemId = @LogicalItemId
  (across ALL shifts/DayParts for that item on that day)

TheoClosedQty = OpenQty + DeliveredQty + TransferQty - RawWasteQty - TheoConsumedQty
  (handled by UpdateStockPeriodBalanceTotals)
```

---

## Notes
- RawWasteCount rows are pre-created by GetOrCreateRawWasteCount (story 3758, completed)
- WasteQty in RawWasteCount is in **units** (user-facing)
- RawWasteQty in StockPeriodBalance is in **portions** (WasteQty × PortionsPerUnit)
- Existing `UpdateStockPeriodBalanceRawWaste` under StockLedger is NOT used — it was built for LocationCountItem flow
- `UpdateStockPeriodBalanceTotals` requires both current and previous day's StockPeriodBalance

---

## Build Progress
- [X] Step 1: Create Server Action + Service Action shell
- [X] Step 2: Input validation (DayPartsId null check, WasteEntries empty check)
- [X] Step 3: Save RawWasteCount loop (GetRawWasteCounts → UpdateRawWasteCount)
- [X] Step 4: Recalculate RawWasteQty aggregate (GetSumOfRawWaste)
- [X] Step 5: Update StockPeriodBalance (entity action with calculated sum)
- [X] Step 6: Call UpdateStockPeriodBalanceTotals (with current + prev day balance)
- [ ] Step 7: Test end-to-end

---

## Next Steps
1. Build frontend UI (entry slideout) — calls SaveRawWasteEntry Service Action
2. Test end-to-end: save waste → verify RawWasteCount updated → verify StockPeriodBalance.RawWasteQty → verify TheoClosedQty recalculated
