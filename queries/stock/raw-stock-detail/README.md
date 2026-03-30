# GetRawStockDetail

## Purpose
Detail-level raw stock report — one row per calendar date for a single LogicalItem.
All values displayed in units (portions ÷ PortionsPerUnit).
Includes a Total row (ReportDate IS NULL).

**Item Detail card** is a separate query (`query-item-detail.sql`) — same pattern as TotalVariance on the list screen.

## Queries

### 1. GetRawStockDetail (`query.sql`)
Main grid — one row per day + Total row.

**Parameters:**
| Parameter | Type | Expand Inline | Notes |
|-----------|------|--------------|-------|
| @SiteId | LongInteger | No | Single site from sidebar |
| @StartDate | Date | No | Date range start |
| @EndDate | Date | No | Date range end |
| @LogicalItemId | LongInteger | No | Single item (from list row click) |

**Output:** 13 columns — see `output-structure.json`

### 2. GetRawStockItemDetail (`query-item-detail.sql`)
Item Detail card — single row with item metadata.

**Parameters:**
| Parameter | Type | Expand Inline | Notes |
|-----------|------|--------------|-------|
| @LogicalItemId | LongInteger | No | Single item (from list row click) |

**Output:** 5 columns — see `output-structure-item-detail.json`

## Tables
- `StockPeriodBalance` — Daily stock data (quantities in portions)
- `StockPeriod` — Site + Date lookup
- `LogicalItem` — Item metadata
- `PhysicalItem` — UnitName, PortionsPerUnit
- `CentralStockItem` — DefaultCountPeriodId (LEFT JOIN)

## Grid Output Columns
| Column | Notes |
|--------|-------|
| ReportDate | NULL for Total row |
| StartingCount | First row's value in Total row |
| StartIsTheo | Red * indicator |
| RawWaste | Summed in Total row |
| Deliveries | Summed in Total row |
| Transfers | Summed in Total row |
| UnitsCPM | Summed in Total row |
| EndCount | Last row's value in Total row |
| CloseQtyIsTheo | Red * indicator |
| VarQty | Last row's value in Total row. NULL if CloseQtyIsTheo = true |
| VarDollar | Last row's value in Total row. NULL if CloseQtyIsTheo = true |
| VarPercent | Total: sum(VarQty)/sum(UnitsCPM) × 100 where CloseQtyIsTheo=false |
| ItemCostAtClose | NULL in Total row |

## Item Detail Card Columns
| Column | Notes |
|--------|-------|
| ItemName | For breadcrumb display |
| ItemType | Food / Paper / Other |
| WrinNumber | WRIN code |
| UnitName | Unit label |
| DefaultCountPeriodId | Count frequency |

## Total Row Identification
- `ReportDate IS NULL` — Total row has no date

## Version History
| Version | Date | Changes |
|---------|------|---------|
| v1.0 | 2026-03-29 | Initial build |
| v1.1 | 2026-03-30 | Split Item Detail card into separate query |
