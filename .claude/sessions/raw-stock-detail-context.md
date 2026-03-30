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
- **Total row identified by ReportDate IS NULL**: No RowType column — Total row has NULL ReportDate.
- **Total row Var %**: Uses sum(VarQty)/sum(UnitsCPM) × 100 across rows where CloseQtyIsTheo = false (per spec). Different from per-row Var % which uses single-day TheoConsumedQty.
- **Total row Start/End Count**: First row's StartingCount, last row's EndCount (not summed).
- **Total row VarQty/VarDollar**: Last row's values (not summed).
- **CAST on quantity columns**: Same safety net as list query for nvarchar columns.
- **InputVar CTE**: Used for @StartDate, @EndDate, @LogicalItemId to handle OutSystems Lazy Parser bug.
- **ItemUnit CTE**: Slimmed-down version of old ItemInfo — only fetches PortionsPerUnit for unit conversion.

## Files Created
- `queries/stock/raw-stock-detail/query.sql` — Main grid (13 output columns)
- `queries/stock/raw-stock-detail/query-item-detail.sql` — Item Detail card (5 output columns)
- `queries/stock/raw-stock-detail/output-structure.json` — 13 columns
- `queries/stock/raw-stock-detail/output-structure-item-detail.json` — 5 columns
- `queries/stock/raw-stock-detail/tests/test-ssms.sql` — SSMS sandbox test
- `queries/stock/raw-stock-detail/tests/test-find-data-march.sql` — Data diagnostic for 29-30 March 2026
- `queries/stock/raw-stock-detail/metadata.json`
- `queries/stock/raw-stock-detail/README.md`

## Changes Log
| Date | Change |
|------|--------|
| 2026-03-29 | v1.0 — Initial build: all-in-one query with item metadata on every row |
| 2026-03-30 | v1.1 — Split Item Detail card into separate query (query-item-detail.sql). Removed 5 metadata columns from main query. Updated test-ssms.sql. Created test-find-data-march.sql. |

## Next Steps
1. Run test-find-data-march.sql to confirm data exists for 29-30 March 2026
2. If data exists, run test-ssms.sql with a real LogicalItemId
3. Wire up in OutSystems (two Advanced SQL blocks: grid + item detail card)
4. User testing

## Quick Resume
To continue:
1. Read session context: `.claude/sessions/raw-stock-detail-context.md`
2. Read table docs: `database-context/tables/StockPeriodBalance/README.md` (+ others)
3. Reference list query for patterns: `queries/stock/raw-stock-list/query.sql`
4. Main query: `queries/stock/raw-stock-detail/query.sql`
5. Item detail query: `queries/stock/raw-stock-detail/query-item-detail.sql`
