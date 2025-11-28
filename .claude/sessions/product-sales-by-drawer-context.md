# Session: Product Sales By Drawer - 2025-11-28

## Original Story/Requirements

**User Request (exact):**
```
Data from following fields:
POS = POSId
Type = based on POD (get this from SWCPosTerminal or SalesFact.POD). (Pass this value into Server Action GetPodFullName).
Close = GTFinal
Open = GTInitial
Difference = Close - Open
OVerring = 0
Cash Refund = SWCCashDrawerTender.RefundAmount (or RefundCount) for TenderType = Cash
Eftpos Refund = SWCCashDrawerTender.RefundAmount (or RefundCount) for TenderType = Eftpos, Doordash, MOP, Ubereats or Delivereasy
Other Receipt = Remove this Column, not needed
GC Sold = SWCCashDrawerTender.NetAmount for TenderType.Category = TENDER_GIFT_Coupon
Gross Sales = Equation in slide
GST = SalesFact.TaxAmount
Net Sales = Equation in slide 1
Non Prod Sales = This field doesn't exist yet, leave it blank
Product Sales = Net Sales - NonProdSales
```

**Additional Info:**
- Story name: "Product Sales By Drawer"
- Filter: Single date and SiteId
- TenderType IDs:
  - Cash = 0
  - Eftpos group = 10, 13, 16, 19, 21
  - Gift Card/Coupon = Category 'TENDER_GIFT_COUPON'
- Use CountedAmount for GC Sold (per user snippet)
- Gross Sales and Net Sales equations = TBD (set to 0 for now)

---

## Status

- [ ] Complete
- [X] In Progress
- [ ] Needs Review

**Current step**: Query built with known requirements, awaiting equation confirmations

**Incomplete items**:
1. GrossSales equation not confirmed (currently 0)
2. NetSales equation not confirmed (currently 0)
3. TenderType.Category field needs verification
4. SiteId filter needs field confirmation
5. Date filter field needs confirmation (using LogOutDateTime)

---

## Tables Documentation Created

- `database-context/tables/SalesFact/` - [NEW] - Sales transaction fact table
- `database-context/tables/SWCPosTerminal/` - [NEW] - POS terminal session data
- `database-context/tables/SWCCashDrawerTender/` - [NEW] - Tender-specific drawer data
- `database-context/tables/SWCCashDrawer/` - [NEW] - Main cash drawer session table

**Note**: All table docs are universal and can be reused by other queries

---

## Queries Created

- `queries/reports/product-sales-by-drawer/` - [IN PROGRESS]
  - Purpose: Cash drawer reconciliation with GT values, refunds, and sales
  - Tables used: SWCCashDrawer, SWCPosTerminal, SWCCashDrawerTender, TenderType, SalesFact
  - Output: POS, Type, GT values, refunds, GC sold, GST, sales calculations
  - Parameters: @SiteId, @Date

---

## Key Decisions

- **DECLARE pattern**: All queries now start with DECLARE statements for easy parameter testing → Rationale: User requested, easier to modify values
- **Query naming**: Using exact story name "product-sales-by-drawer" → Rationale: New rule in claude.md
- **TenderType grouping**: Using IN clause for Eftpos group (10,13,16,19,21) → Rationale: Matches user snippet pattern
- **GC Sold field**: Using CountedAmount instead of NetAmount → Rationale: User provided snippet showed CountedAmount
- **Incomplete equations**: Set to 0 rather than guessing → Rationale: Better to be explicit about unknowns
- **Table docs made universal**: Removed query-specific language → Rationale: Reusable across all queries

---

## Next Steps (if incomplete)

1. **Get equations** - User needs to provide GrossSales and NetSales formulas
2. **Verify TenderType table** - Check if Category field exists
3. **Confirm date filter** - Verify LogOutDateTime is correct field for @Date filter
4. **Test SiteId** - Verify SWCCashDrawer has SiteId field or needs different join
5. **Test query** - Run with real data once equations are confirmed
6. **Update calculations** - Replace 0s with actual equations when provided

---

## Notes for Next Session

- **User snippets provided**: TenderType logic with CASE WHEN pattern - reused in query
- **Pod handling**: Type column returns Pod value, needs GetPodFullName server action in OutSystems
- **Images not needed**: User confirmed no need to save images to table docs
- **Session tracking**: Context file designed for anyone to continue work
- **Pending equations**: Don't guess - wait for user confirmation

---

## Quick Resume

**To continue this work:**

1. **Read table docs**:
   - `database-context/tables/SWCCashDrawer/README.md` - GT values
   - `database-context/tables/SWCCashDrawerTender/README.md` - Refunds
   - `database-context/tables/SalesFact/README.md` - Tax amounts
   - `database-context/tables/SWCPosTerminal/README.md` - Pod/Type

2. **Check current query**:
   - `queries/reports/product-sales-by-drawer/query.sql`
   - Review TODO comments at bottom
   - DECLARE parameters at top for easy testing

3. **Continue from**:
   - Waiting for GrossSales and NetSales equations from user
   - Once received, update lines with "TODO: Confirm equation"
   - Test TenderType.Category availability
   - Validate date and SiteId filters

4. **Ask user for**:
   - "What's the equation for Gross Sales?"
   - "What's the equation for Net Sales?"
   - "Does TenderType table have a Category field?"

---

## Repository State

**Files created this session**:
- `database-context/tables/SalesFact/README.md`
- `database-context/tables/SWCPosTerminal/README.md`
- `database-context/tables/SWCCashDrawerTender/README.md`
- `database-context/tables/SWCCashDrawer/README.md`
- `queries/reports/product-sales-by-drawer/query.sql`
- `queries/reports/product-sales-by-drawer/README.md`
- `queries/reports/product-sales-by-drawer/metadata.json`
- `.claude/sessions/product-sales-by-drawer-context.md` (this file)

**Files updated**:
- `.claude/claude.md` - Added DECLARE pattern rule, query naming rule, table doc guidelines

**Ready for**: Equation confirmations and testing
