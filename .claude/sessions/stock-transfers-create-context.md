# Session: Stock Transfers Create - 2026-04-01

## Original Story/Requirements
**PRD 1.3 - Inter-Store Stock Transfers**, Story 1.3.5: Create a Transfer

Create Transfer screen — sending store user selects receiving site, adds line items with quantities, saves to pending. No SQL queries needed — all handled via OutSystems aggregates and server actions.

## Status
- [ ] Complete / [X] In Progress / [ ] Needs Review
- Current step: Screen layout built, item dropdown wired, On Change handler in progress
- Incomplete items: Quantity On Change logic, Total row recalc, Save to Pending action, price lookup fix

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

## Pending Steps
- [ ] Complete `physicalItemDropdownOnChanged` — assign item fields + price
- [ ] Quantity On Change handler (Cartons/Inners/Units → recalc QtyTotal + NetAmount + Total row)
- [ ] RemoveOnClick — remove row + recalc total
- [ ] SaveTransfer — validation + create StockMovement + Transfer + StockMovementLine records
- [ ] Update BO_RawItemPrice table doc with corrected join path

## Key Decisions
- **No SQL queries**: All data via OutSystems aggregates (items, price) and server actions (save)
- **PhysicalItem** (not LogicalItem): PRD explicitly uses PhysicalItemId on StockMovementLine
- **Total row at position 0**: Identified by `Description = "Total-Description"`
- **QtyTotal formula**: `(QtyOfCases × UnitsInCarton × UnitsInInners) + (QtyOfInners × UnitsInInners) + QtyOfLoose`
- **NetAmount formula**: `QtyTotal × UnitPrice`
- **GST hardcoded at 10%** for NZ (confirmed by user)

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
1. Complete item dropdown On Change (assign fields + price via corrected aggregate)
2. Build quantity On Change handler
3. Build RemoveOnClick
4. Build SaveTransfer server action
5. Update table docs (BO_RawItemPrice join path, add BO_RawItem doc)

## Quick Resume
1. Read this context
2. Continue from: `physicalItemDropdownOnChanged` — need to wire up the price aggregate using the corrected join path (BO_RawItemPrice → BO_RawItem → PhysicalItem)
