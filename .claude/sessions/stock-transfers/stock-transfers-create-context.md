# Session: Stock Transfers Create - 2026-04-01

## Original Story/Requirements
**PRD 1.3 - Inter-Store Stock Transfers**, Story 1.3.5: Create a Transfer

Create Transfer screen — sending store user selects receiving site, adds line items with quantities, saves to pending. No SQL queries needed — all handled via OutSystems aggregates and server actions.

## Status
- [X] Complete / [ ] In Progress / [ ] Needs Review
- All client actions wired: QuantityOnChanged, RemoveOnClick, physicalItemDropdownOnChanged (with recalc)
- SaveTransfer server action built in Stock_CS (CreateTransferRecord): validation + StockMovement + Transfer + StockMovementLines
- Frontend save flow: assigns payload, removes Total row (index 0), calls server action, exception handler for validation errors
- Transfer successfully created and visible in list query

## Screen Structure
- **Block**: `StockTransferCreateScreenBlock`
- **CSS class**: `transfer-form-grid` (3-column grid, memo spans full width via `memo-field`)
- **Local variable**: `TransferLineItems` (List of `TransferLineItem` struct)
- **Total row**: Inserted at position 0 with `Description = "Total-Description"`
- **Line items**: Appended via `ListAppend` with empty struct
- **If widget**: Per row, switches between Total row layout and Line item layout based on `Description = "Total-Description"`

## TransferLineItem Struct
```json
{
  "PhysicalItemId":  "LongInteger",
  "WrinNumber":      "Text",
  "Description":     "Text",
  "QtyOfCases":      "Integer",
  "QtyOfInners":     "Integer",
  "QtyOfLoose":      "Integer",
  "QtyTotal":        "Integer",
  "UnitPrice":       "Decimal",
  "NetAmount":       "Decimal",
  "UnitsInCarton":   "Integer",
  "UnitsInInners":   "Integer"
}
```

## Aggregates
1. **GetPhysicalItemsByConceptId** — Item dropdown, filtered by `PhysicalItem.ConceptId = Site.ConceptId`
2. **GetItemPrice** — Price lookup on item selection (see pinned issue below)

## Client Actions
- `InitializeDatagrid` — Inserts Total row at position 0
- `AddLineItemOnClick` — Appends empty line item row
- `physicalItemDropdownOnChanged` — Populates line fields + resolves price
- `RemoveOnClick` — Removes line + recalcs total
- `SaveTransfer` — Validates + creates records

## Completed Steps
- [X] Screen layout with `transfer-form-grid` CSS (3-col: From, To, Date + full-width Memo)
- [X] TransferLineItem struct created
- [X] DataGrid initialized with Total row at position 0
- [X] AddLineItem appends empty row
- [X] Item dropdown wired: `GetPhysicalItemsByConceptId.List`, Value=Id, Label=WrinNumber + " — " + ItemName
- [X] `physicalItemDropdownOnChanged` handler created with DropdownSearchId + SelectedOptionList params
- [X] If widget per row: Total row vs Line item row
- [X] `QuantityOnChanged` — recalcs QtyTotal + NetAmount for changed row + Total row (index 0)
- [X] `RemoveOnClick` — removes row + recalcs Total row
- [X] `physicalItemDropdownOnChanged` — recalcs Total row after item/price change
- [X] QtyTotal formula fix: `If(UnitsInCarton = 0, 1, UnitsInCarton)` / `If(UnitsInInners = 0, 1, UnitsInInners)` to prevent zero multiplication
- [X] QtyTotal formula fix (2026-04-09): Removed `× UnitsInInners` from cartons — UnitsInCarton is already total units per carton, not inners per carton

## Pending Steps
- [X] SaveTransfer — validation + create StockMovement + Transfer + StockMovementLine records
- [ ] Update BO_RawItemPrice table doc with corrected join path (low priority)

## Key Decisions
- **No SQL queries**: All data via OutSystems aggregates (items, price) and server actions (save)
- **PhysicalItem** (not LogicalItem): PRD explicitly uses PhysicalItemId on StockMovementLine
- **Total row at position 0**: Identified by `Description = "Total-Description"`
- **QtyTotal formula**: `(QtyOfCases × If(UnitsInCarton=0,1,UnitsInCarton)) + (QtyOfInners × If(UnitsInInners=0,1,UnitsInInners)) + QtyOfLoose`
- **UnitsInCarton** = total individual units per carton (already resolved to base unit, NOT inners per carton)
- **UnitsInInners** = total individual units per inner (already resolved to base unit)
- **Zero conversion factor fix**: When UnitsInCarton or UnitsInInners = 0 (item has no carton/inner packing level), treat as 1 to prevent zeroing out the calculation
- **Formula fix (2026-04-09)**: Removed extra `× UnitsInInners` from cartons part — old formula double-counted by treating UnitsInCarton as "inners per carton"
- **NetAmount formula**: `QtyTotal × UnitPrice`
- **GST dynamic by country**: AU = 10%, NZ = 15%, Fj = 15% — uses @CountryCode param from GetTenantCountryCode()

## 📌 PINNED: Price Lookup Join Path (2026-04-01)
**Status**: Needs correction in table docs

**Problem**: PRD says price joins via `PhysicalItem.ConceptId + WRIN = BO_RawItemPrice.ConceptId + WRIN`. But the actual data uses a bridge table:

**Actual join path (confirmed from OutSystems aggregate):**
```
BO_RawItemPrice.Refkey = BO_RawItem.Current_BORawItemPriceId  (Only With)
BO_RawItem.Refkey = PhysicalItem.BO_RawItemId                  (Only With)
```

**Impact**:
- The `Current_BORawItemPriceId` FK already points to the active/latest price — no need for `Effective <= GETDATE() ORDER BY Effective DESC`
- Need to create `BO_RawItem` table doc
- Need to update `BO_RawItemPrice` table doc with corrected join
- Need to update `PhysicalItem` table doc noting `BO_RawItemId` relationship

**Action needed**: Update table docs once price lookup is verified working in OutSystems.

## 📌 PINNED: Transfer Date Field (2026-04-01)
**Status**: Clarification needed

**PRD says**: No date field on create — date set automatically on approval.
**Mockup shows**: Transfer Date field on the create screen.
**Current**: Date field exists on the screen. Need to confirm with user which behaviour is correct.

## CSS
```css
.transfer-info-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 16px 24px;
    padding: 16px;
}
.transfer-info-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    width: 100%;
    margin-bottom: 16px;
}
.transfer-form-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 20px 24px;
    padding: 16px 0;
}
.transfer-form-grid .memo-field {
    grid-column: 1 / -1;
}
.btn-remove {
    background-color: transparent;
    color: #cc0000;
    border: 1.5px solid #cc0000;
    padding: 6px 16px;
    font-weight: 600;
    font-size: 14px;
    border-radius: 4px;
    cursor: pointer;
}
```

## Next Steps
1. Build SaveTransfer server action (validation + create records)
2. Disable qty inputs until item is selected
3. Update table docs (BO_RawItemPrice join path, add BO_RawItem doc)

## Quick Resume
1. Read this context
2. Continue from: `SaveTransfer` — all On Change handlers are done, need to build the save action

## PRD Reference (1.3 Inter-Store Stock Transfers)

### Story 1.3.5: Create a Transfer
**Acceptance Criteria:**
- Create Transfer screen accessible only to StockInvoice_Admin users
- Page title breadcrumb: "Transfers › New Transfer"
- Header form fields: From (auto-populated, read-only), To (dropdown of other accessible sites), Memo (optional)
- No date field — transfer date set automatically on approval (local business date)
- Stock lines: Add Line Item button, each row has item dropdown, Description (auto), Cartons, Inners, Units, Total Units, Price/Unit (read-only from BO_RawItemPrice), Cost
- Quantity inputs disabled until item is selected
- Running Total row at top updates as quantities change
- Save to Pending button triggers save

**On Save:**
- StockMovement: MovementTypeId = Transfer, DeliverySiteId = receiving site, Date = null (set on approval)
- Transfer: FromSiteId = sending site, IsApproved = false, ApprovedByUserId = null, ApprovedAt = null
- StockMovementLine: one per line with non-zero quantity
- Sending store user auto-approves outgoing side
- Redirect to Transfers list (Pending view)

**Save Validation:**
- Receiving site required
- At least one line with selected item and non-zero quantity

### Data Model (Save)
**StockMovement:**
- MovementTypeId (int) — Transfer enum
- DeliverySiteId (int) — receiving site
- Date (date) — null until approval
- NetAmount, TaxAmount, GrossAmount (decimal) — calculated on approval
- CreatedBy (int), CreatedAt (datetime)

**Transfer:**
- StockMovementId (int) — FK → StockMovement.Id (PK)
- FromSiteId (int) — sending site
- Comment (nvarchar 500) — memo
- IsApproved (bit) — default false
- ApprovedByUserId (int) — null
- ApprovedAt (datetime) — null

**StockMovementLine:**
- StockMovementId (int) — FK → StockMovement.Id
- PhysicalItemId (int)
- Description (nvarchar 255) — snapshot
- QtyOfCases, QtyOfInners, QtyOfLoose, QtyTotal (int)
- UnitPrice (decimal 18,5) — resolved at save time
- NetAmount (decimal 18,4) — QtyTotal × UnitPrice

### QtyTotal Formula (Corrected 2026-04-09)
`(QtyOfCases × UnitsInCarton) + (QtyOfInners × UnitsInInners) + QtyOfLoose`
- UnitsInCarton = total individual units per carton (already resolved to base unit)
- UnitsInInners = total individual units per inner (already resolved to base unit)
- **Zero-safety**: Treat 0 as 1 to prevent zeroing out when item has no carton/inner packing level
- **Old formula was wrong**: `Cases × UnitsInCarton × UnitsInInners` double-counted because UnitsInCarton is already the total units, not inners per carton

### Unit Price Resolution (PRD)
```sql
SELECT TOP 1 Value
FROM BO_RawItemPrice
WHERE ConceptId = @ConceptId
  AND WRIN = @WRIN
  AND Effective <= GETDATE()
ORDER BY Effective DESC
```
**Actual implementation**: Uses bridge table path: BO_RawItemPrice → BO_RawItem → PhysicalItem (see pinned issue)
