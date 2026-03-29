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
- Current step: All files written. Query runs clean in OutSystems but no StockPeriodBalance data yet to verify numbers.
- Incomplete items: Verify with real data, user testing

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

### Item Detail Card (fixed metadata)
| Field | Source |
|-------|--------|
| Item Type | LogicalItem.ItemType |
| Count Frequency | CentralStockItem.DefaultCountPeriodId |
| WRIN | LogicalItem.WrinNumber |
| Unit | PI.UnitName |

### Parameters
| Parameter | Expand Inline | Notes |
|-----------|--------------|-------|
| @SiteId | No | Single site from sidebar |
| @StartDate | No | Date range start |
| @EndDate | No | Date range end |
| @LogicalItemId | No | Single item (from row click) |

### Filters
- Date Range only (no item search, no product type, no count frequency on detail screen)

## Key Decisions
- **Item Detail card in same query**: Item metadata (ItemName, ItemType, WrinNumber, UnitName, DefaultCountPeriodId) included on every row via ItemInfo CTE. OutSystems reads from first row. Avoids a separate query.
- **Total row identified by ReportDate IS NULL**: No RowType column — Total row has NULL ReportDate.
- **Total row Var %**: Uses sum(VarQty)/sum(UnitsCPM) × 100 across rows where CloseQtyIsTheo = false (per spec). Different from per-row Var % which uses single-day TheoConsumedQty.
- **Total row Start/End Count**: First row's StartingCount, last row's EndCount (not summed).
- **Total row VarQty/VarDollar**: Last row's values (not summed).
- **CAST on quantity columns**: Same safety net as list query for nvarchar columns.
- **InputVar CTE**: Used for @StartDate, @EndDate, @LogicalItemId to handle OutSystems Lazy Parser bug.

## Files Created
- `queries/stock/raw-stock-detail/query.sql`
- `queries/stock/raw-stock-detail/tests/test-ssms.sql`
- `queries/stock/raw-stock-detail/output-structure.json`
- `queries/stock/raw-stock-detail/metadata.json`
- `queries/stock/raw-stock-detail/README.md`

## Next Steps
1. Write query.sql
2. Write test-ssms.sql
3. Create output-structure.json
4. Create README.md and metadata.json
5. Test and verify

## Quick Resume
To continue:
1. Read session context: `.claude/sessions/raw-stock-detail-context.md`
2. Read table docs: `database-context/tables/StockPeriodBalance/README.md` (+ others)
3. Reference list query for patterns: `queries/stock/raw-stock-list/query.sql`
