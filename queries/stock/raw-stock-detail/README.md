# GetRawStockDetail

## Purpose
Detail-level raw stock report — one row per calendar date for a single LogicalItem.
All values displayed in units (portions ÷ PortionsPerUnit).
Includes a Total row and Item Detail card metadata.

## Tables
- `StockPeriodBalance` — Daily stock data (quantities in portions)
- `StockPeriod` — Site + Date lookup
- `LogicalItem` — Item metadata
- `PhysicalItem` — UnitName, PortionsPerUnit
- `CentralStockItem` — DefaultCountPeriodId

## Parameters
| Parameter | Type | Expand Inline | Notes |
|-----------|------|--------------|-------|
| @SiteId | LongInteger | No | Single site from sidebar |
| @StartDate | Date | No | Date range start |
| @EndDate | Date | No | Date range end |
| @LogicalItemId | LongInteger | No | Single item (from list row click) |

## Output Columns

### Grid Columns
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
| VarQty | Last row's value in Total row. Blank if CloseQtyIsTheo = true |
| VarDollar | Last row's value in Total row. Blank if CloseQtyIsTheo = true |
| VarPercent | Per-row: VarQty ÷ UnitsCPM × 100. Total: sum(VarQty)/sum(UnitsCPM) × 100 where CloseQtyIsTheo=false |
| ItemCostAtClose | NULL in Total row |

### Item Detail Card Columns (same on every row)
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
