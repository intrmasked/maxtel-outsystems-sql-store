# Raw Waste — PRD & Design

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_boards/board/t/Scheduling%20Team/Stories?workitem=3758

---

## Overview

Raw Waste allows staff to record food items discarded during each shift of a working day, tracked by logical item and unit count. It provides visibility into waste costs across shifts and supports sites that manage stock entry manually (without the Stock Count app).

---

## User Stories

### 1.7.1: View Raw Waste List
Displays one row per day with columns for each shift (Overnight, Breakfast, Day, Night) and a daily total. Each row shows a completion status indicating how many shifts have entries. Filters include date range (preset options + custom). Clicking a row navigates to the day detail view.

### 1.7.2: View Raw Waste Detail
Displays a cross-tab table with logical items as rows and shifts as column groups. Each cell shows quantity (in the item's UOM) and estimated cost value. Items are grouped by product category. Shows per-shift totals and a day total.

### 1.7.3: Enter Raw Waste
Accessible via an entry panel opened from the list or detail view. User selects date and shift before entering quantities. Items are displayed with their UOM (derived from the default physical item of each logical item); quantities are entered as whole units except for weight/volume UOMs (KG, LTR). Items can be filtered by menu type (e.g. Breakfast only, Regular only) and searched by name. Only items with a quantity entered are saved; zero-quantity rows are not persisted. Existing entries for the selected date and shift are pre-populated for editing. Total estimated waste cost updates in real time as quantities are entered. webstock_view users cannot access the entry panel.

### 1.7.4: Read-Only Mode for Stock Count Users
The entry panel is not accessible; the "+ Add / Edit" button is hidden. Waste quantities entered in the Stock Count app are automatically reflected in the Raw Waste browse and detail views.

### 1.7.5: Print Waste Form
Accessible via the printer icon in the sidebar. User configures: date range, site, shift (or all shifts), and item filter (menu type). Generates a PDF listing items with their UOM and a blank quantity column for manual entry. Unit costs are shown on the form for reference.

---

## Data Model

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

### DayParts
| Column | Type | Description |
|--------|------|-------------|
| Id | Long Integer | PK |
| ConceptId | Long Integer | Concept/brand identifier |
| Order | Integer | Display order (1-4) |
| Label | Text | Shift name: Overnight, Breakfast, Day, Night |
| StartTime | Time | Shift start |
| EndTime | Time | Shift end |

### LogicalItemSiteConfig
| Column | Type | Description |
|--------|------|-------------|
| Id | Long Integer | PK |
| LogicalItemId | Long Integer | FK → LogicalItem |
| SiteId | Long Integer | FK → Site |
| IsWasteable | Boolean | Whether item is tracked for waste |
| IsActive | Boolean | Whether item is active at site |

### Related Tables (existing)
- **StockPeriod** — site + date periods
- **LogicalItem** — master item list (has DefaultPhysicalItemId)
- **PhysicalItem** — unit names, UnitsInCarton, PortionsPerUnit
- **BO_RawItemPrice** — historical prices (ConceptId + WRIN + Effective)
- **StockPeriodBalance** — stock balance (RawWasteQty field)

Full table docs: `database-context/tables/[table-name]/README.md`

---

## Business Rules

| Rule | Detail |
|------|--------|
| Stock Count gate | If user holds StockCountUser or StockCountAdmin role, Raw Waste screen is read-only |
| Wasteable items | Only items where LogicalItemSiteConfig.IsActive = 1 AND IsWasteable = 1 |
| UOM source | From default physical item (LogicalItem.DefaultPhysicalItemId → PhysicalItem.UnitName) |
| Shift structure | Each workday has exactly 4 shifts: Overnight, Breakfast, Day, Night |
| Waste quantities | Whole numbers for EA-type items; decimal for KG and LTR |
| Zero quantities | Line items with quantity = 0 are not saved |

---

## Key Logic

### 1. GetOrCreate RawWasteCount rows
- Input: SiteId, Date
- GetOrCreateStockPeriod → StockPeriodId
- If rows exist → return
- If not → create one row per (wasteable LogicalItem × DayPart)
- CostPerUnit = BO_RawItemPrice.Value / PhysicalItem.UnitsInCarton (most recent Effective <= today)

### 2. Save waste entry
- Input: StockPeriodId, DayPartsId, list of { LogicalItemId, WasteQty }
- UPDATE RawWasteCount SET WasteQty, LastUpdatedAt for each item
- Call UpdateStockPeriodBalance for each affected LogicalItemId

### 3. UpdateStockPeriodBalance after waste change
- RawWasteQty = SUM(RawWasteCount.WasteQty × PhysicalItem.PortionsPerUnit) across all DayParts
- Then call UpdateStockPeriodBalanceTotals to recalculate TheoClosedQty

### 4. Stock Count sync (LocationCountItem → RawWasteCount)
- Triggered on LocationCountItem change for Stock Count sites
- Maps CentralStockItem → LogicalItem, Location → DayParts
- Updates RawWasteCount and StockPeriodBalance

### 5. Daily Waste Sheet report
- Input: StartDate, EndDate, SiteId, MenuType
- Lists items with WRIN, Menu, Description, UOM, UnitCost
- Returns JSON or PDF via CreatePDFReportFromJSON

---

## Integration Points

| Direction | System / Event | Detail |
|-----------|---------------|--------|
| Inbound | Stock Count app — LocationCountItem change | Triggers sync to write waste into RawWasteCount |
| Internal | UpdateStockPeriodBalanceRawWaste | Must read from RawWasteCount (modified from LocationCountItem) |
| Internal | UpdateStockPeriodBalanceTotals | Called after every RawWasteQty update |
| Internal | GetOrCreateStockPeriod | Resolves or creates StockPeriod row |
| Outbound | Report_CS — DailyWasteSheet | New report registered in SupportedReport |
