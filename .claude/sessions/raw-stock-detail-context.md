# Session: Raw Stock — Detail Screen | 2026-03-29

## Original Story/Requirements
Feature 3.1 — Raw Stock Detail Screen. Route: `Stock > Raw Stock > [Item]`.
One row per calendar date (StockPeriod) for a single LogicalItem.
All values displayed in units (portions ÷ PortionsPerUnit).
Includes a Totals row with specific rules per column.
Includes an Item Detail card (fixed metadata, not date-range dependent).

From spec v0.4, Section 11.

## Status
- [ ] Complete / [X] In Progress / [ ] Needs Review
- Current step: Query split done (v1.1). Item Detail card now separate query. Need to test with real data.
- Incomplete items: Verify with real data, user testing, OutSystems wiring

## Tables Used
- `StockPeriodBalance` — One row per period + LogicalItem (all qty in portions)
- `StockPeriod` — One record per Site + Date
- `LogicalItem` — Item metadata (ItemName, ItemType, WrinNumber)
- `PhysicalItem` — UnitName, PortionsPerUnit conversion
- `CentralStockItem` — DefaultCountPeriodId for Item Detail card

Table docs already exist from raw-stock-list work.

## Spec Summary (Section 11)

### Data Source
Same joins as list screen but filtered to a **single LogicalItemId** and active site.
One row per StockPeriod.Date in the selected date range.

### Columns (per row = per day)
| Column | Source | Notes |
|--------|--------|-------|
| Date | StockPeriod.Date | |
| Starting Count | SB.OpenQty ÷ PPU | Red * if StartIsTheo = true |
| Raw Waste | SB.RawWasteQty ÷ PPU | |
| Deliveries | SB.DeliveredQty ÷ PPU | |
| Transfers | SB.TransferQty ÷ PPU | |
| Units CPM | SB.TheoConsumedQty ÷ PPU | |
| End Count | Actual or Theo ÷ PPU | Red * if CloseQtyIsTheo = true |
| Var Qty | (Actual - Theo) ÷ PPU | Blank if CloseQtyIsTheo = true |
| Var $ | VarQty × ItemCostAtClose | Blank if CloseQtyIsTheo = true |
| Var % | VarQty ÷ (TheoConsumedQty ÷ PPU) × 100 | Blank if CloseQtyIsTheo = true or TheoConsumedQty = 0 |

### Totals Row Rules
| Field | Value |
|-------|-------|
| Starting Count | First row's OpenQty ÷ PPU |
| Raw Waste | Sum across all rows ÷ PPU |
| Deliveries | Sum across all rows ÷ PPU |
| Transfers | Sum across all rows ÷ PPU |
| Units CPM | Sum across all rows ÷ PPU |
| End Count | Last row's End Count |
| Var Qty | Last row's Var Qty |
| Var $ | Last row's Var $ |
| Var % | sum(Actual-Theo) / sum(TheoConsumed) × 100 across rows where CloseQtyIsTheo = false |

### Item Detail Card (separate query — query-item-detail.sql)
| Field | Source |
|-------|--------|
| Item Name | LogicalItem.ItemName |
| Item Type | LogicalItem.ItemType |
| Count Frequency | CentralStockItem.DefaultCountPeriodId |
| WRIN | LogicalItem.WrinNumber |
| Unit | PI.UnitName |

### Parameters

**GetRawStockDetail (query.sql):**
| Parameter | Expand Inline | Notes |
|-----------|--------------|-------|
| @SiteId | No | Single site from sidebar |
| @StartDate | No | Date range start |
| @EndDate | No | Date range end |
| @LogicalItemId | No | Single item (from row click) |

**GetRawStockItemDetail (query-item-detail.sql):**
| Parameter | Expand Inline | Notes |
|-----------|--------------|-------|
| @LogicalItemId | No | Single item (from row click) |

### Filters
- Date Range only (no item search, no product type, no count frequency on detail screen)

## Key Decisions
- **Item Detail card split into separate query (v1.1)**: Same pattern as TotalVariance on list screen. OutSystems calls two Advanced SQL blocks independently. Avoids repeating metadata on every grid row.
- **RowType column added (v1.2)**: 'Total' or 'Detail' — easier identification in OutSystems than checking NULL ReportDate.
- **ReportDate changed to Text (v1.2)**: Total row shows 'Total', detail rows show 'dd Mon yyyy' format. Better for exports.
- **ItemType resolved in SQL (v1.2)**: CASE maps F→Food, P→Paper, S→Supplies, H→Happy Meal, N→No Recipe.
- **CountFrequency resolved in SQL (v1.2)**: JOIN to CountPeriod table for label instead of raw ID.
- **CSI join through PhysicalItem (v1.3)**: Changed from `LI.ConceptId + LI.WrinNumber` → `PI.ConceptId + PI.WrinNumber = CSI.WrinNumberClean`.
- **Total row Var %**: Uses sum(VarQty)/sum(UnitsCPM) × 100 across rows where CloseQtyIsTheo = false (per spec). Different from per-row Var % which uses single-day TheoConsumedQty.
- **Total row Start/End Count**: First row's StartingCount, last row's EndCount (not summed).
- **Total row VarQty/VarDollar**: Last row's values (not summed).
- **CAST on quantity columns**: Same safety net as list query for nvarchar columns.
- **InputVar CTE**: Used for @StartDate, @EndDate, @LogicalItemId to handle OutSystems Lazy Parser bug.
- **ItemUnit CTE**: Slimmed-down version of old ItemInfo — only fetches PortionsPerUnit for unit conversion.

## 📌 PINNED: Variance Data Issue (2026-03-31)
**Status**: Pending business/data team clarification

**Problem**: On 30 March 2026 (SiteId 3187), all Paper items have `CloseQtyIsTheo = False` with `ActualClosedQty = 0`, while `TheoClosedQty` is large negative. This produces massive positive variances (e.g. BAG FRIES SMALL: VarQty = 691, Var% = 100%).

**Root cause options**:
1. Real count — someone entered 0 for all items (unlikely for 65+ items)
2. System reset/close — period closed and system defaulted ActualClosedQty = 0
3. Source system bug — CloseQtyIsTheo should be True for these rows

**Impact**: Affects both list and detail screens. Query logic is correct (`Actual - Theo` when `CloseQtyIsTheo = False`). The data itself may be wrong.

**Action needed**: Confirm with stock data team what `ActualClosedQty = 0 + CloseQtyIsTheo = False` means when TheoClosedQty is negative. If it's not a real count, we may need a guard clause in SQL.

**Diagnostic test**: `queries/stock/raw-stock-list/tests/test-variance-diagnostic.sql`

## Files Created
- `queries/stock/raw-stock-detail/query.sql` — Main grid (14 output columns incl. RowType)
- `queries/stock/raw-stock-detail/query-item-detail.sql` — Item Detail card (5 output columns)
- `queries/stock/raw-stock-detail/output-structure.json` — 14 columns
- `queries/stock/raw-stock-detail/output-structure-item-detail.json` — 5 columns
- `queries/stock/raw-stock-detail/outsystems-expressions.md` — All column expressions + styles
- `queries/stock/raw-stock-detail/tests/test-ssms.sql` — SSMS sandbox test
- `queries/stock/raw-stock-detail/tests/test-item-detail.sql` — Item Detail card test
- `queries/stock/raw-stock-detail/tests/test-find-data-march.sql` — Data diagnostic for 29-30 March 2026
- `queries/stock/raw-stock-detail/metadata.json`
- `queries/stock/raw-stock-detail/README.md`

## Changes Log
| Date | Change |
|------|--------|
| 2026-03-29 | v1.0 — Initial build: all-in-one query with item metadata on every row |
| 2026-03-30 | v1.1 — Split Item Detail card into separate query. Added RowType column. ReportDate→Text. Resolved ItemType codes + CountPeriod label. Created outsystems-expressions.md. |
| 2026-03-31 | v1.3 — Changed CSI join from LI→CSI to PI→CSI (PhysicalItem path). Pinned variance data issue. |

## Next Steps
1. 📌 Resolve variance data issue (pending business team clarification)
2. Wire up in OutSystems (two Advanced SQL blocks: grid + item detail card)
3. User testing with real data

## Quick Resume
To continue:
1. Read session context: `.claude/sessions/raw-stock-detail-context.md`
2. Read table docs: `database-context/tables/StockPeriodBalance/README.md` (+ others)
3. Reference list query for patterns: `queries/stock/raw-stock-list/query.sql`
4. Main query: `queries/stock/raw-stock-detail/query.sql`
5. Item detail query: `queries/stock/raw-stock-detail/query-item-detail.sql`
