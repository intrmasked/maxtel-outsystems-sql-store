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
- [X] In Testing (User actively testing)
- [ ] Needs Review

**Current step**: All equations implemented - User is now testing the query

**Complete items**:
1. ✅ GrossSales equation implemented: Difference - Overring - CashRefund - EftposRefund - OtherReceipt - GCSold
2. ✅ NetSales equation implemented: GrossSales - GST
3. ✅ NonProdSales implemented: SUM(NetAmount) WHERE ProductSaleTypeId = 2
4. ✅ ProductSales implemented: NetSales - NonProdSales
5. ✅ TenderType.Category field verified (exists)
6. ✅ SiteId filter updated (uses SWCPeriod.SiteId)
7. ✅ Date filter updated (uses SWCPeriod.BusDate)
8. ✅ SalesFact usage confirmed (joins via SWCPeriodId)
9. ✅ GROUP BY clause error fixed (added sfNonProd.NonProdSales)
10. ✅ DB optimization guidelines added to claude.md

**Testing in progress**:
- User is actively testing the query with production data
- Waiting for test results and feedback
- May need adjustments based on test findings

**Pending (after testing)**:
- GetPodFullName server action validation
- Index implementation by DBA

---

## Tables Documentation Created

- `database-context/tables/SalesFact/` - [NEW] - Sales transaction fact table
- `database-context/tables/SWCPosTerminal/` - [NEW] - POS terminal session data
- `database-context/tables/SWCCashDrawerTender/` - [NEW] - Tender-specific drawer data
- `database-context/tables/SWCCashDrawer/` - [NEW] - Main cash drawer session table
- `database-context/tables/SWCPeriod/` - [NEW] - Operating period with SiteId and BusDate

**Note**: All table docs are universal and can be reused by other queries

---

## Queries Created

- `queries/reports/product-sales-by-drawer/` - [IN TESTING]
  - Purpose: Cash drawer reconciliation with GT values, refunds, and sales
  - Tables used: SWCPeriod, SWCCashDrawer, SWCPosTerminal, SWCCashDrawerTender, TenderType, SalesFact
  - Output: POS, Type, GT values, refunds, GC sold, GST, sales calculations (GrossSales, NetSales, ProductSales)
  - Parameters: @SiteId (via SWCPeriod), @Date (BusDate)
  - Index recommendations: 5 indexes documented (3 High/Critical impact)
  - Status: All equations implemented, GROUP BY fixed, user is testing with production data

---

## Key Decisions

- **DECLARE pattern**: All queries now start with DECLARE statements for easy parameter testing → Rationale: User requested, easier to modify values
- **Query naming**: Using exact story name "product-sales-by-drawer" → Rationale: New rule in claude.md
- **TenderType grouping**: Using IN clause for Eftpos group (10,13,16,19,21) → Rationale: Matches user snippet pattern
- **GC Sold field**: Using CountedAmount instead of NetAmount → Rationale: User provided snippet showed CountedAmount
- **Incomplete equations**: Set to 0 rather than guessing → Rationale: Better to be explicit about unknowns
- **Table docs made universal**: Removed query-specific language → Rationale: Reusable across all queries
- **SWCPeriod added**: Primary filter table for SiteId and BusDate → Rationale: SWC tables don't have direct SiteId
- **SalesFact via SWCPeriodId**: Join through OperatingPeriodId → Rationale: User confirmed SWCPeriodId is populated
- **SalesFact filters**: DatePeriodDimensionId = 15, exclude empty PosId/Pod → Rationale: User specified standard filters
- **Index recommendations**: Added to README.md only (not in query.sql) → Rationale: User requested clean query files
- **Table naming convention**: Use {TableName} format, not [dbo].[TableName] → Rationale: OutSystems standard convention
- **SQL Server 2014+ target**: All queries compatible with SQL 2014+ → Rationale: Production environment requirement
- **GrossSales formula**: Difference - Overring - CashRefund - EftposRefund - OtherReceipt - GCSold → Rationale: User provided calculation from image
- **NetSales formula**: GrossSales - GST → Rationale: User specified
- **NonProdSales filter**: ProductSaleTypeId = 2 in SalesFact → Rationale: User specified product type IDs (1=product, 2=non-product)
- **ProductSales calculation**: NetSales - NonProdSales → Rationale: Per original requirements
- **GROUP BY clause fix**: Added sfNonProd.NonProdSales to GROUP BY → Rationale: Fixed SQL error for aggregated subquery columns
- **DB optimization priority**: Minimize database hits, use single query with JOINs/subqueries → Rationale: User requested performance optimization guidelines
- **Query completion policy**: NEVER mark complete until user explicitly confirms → Rationale: User must confirm testing passed before marking complete
- **Session update mandate**: Update session context on EVERY change → Rationale: Think on every change, keep context in sync for team collaboration
- **SalesFact mandatory filters**: ALWAYS set unused dimension IDs to NULL → Rationale: Prevents double-counting in fact table aggregation, ensures accurate sums (ProductMenuId, TenderTypeId, OperationId, OperationKindId, SWCCashDrawerId, SaleTypeId must be NULL if not used)
- **SalesFact per-POS grouping**: GROUP BY SWCPeriodId AND PosId, JOIN on both → Rationale: Fixed negative sales values - each POS must get only its own GST/NonProdSales, not totals for all POS terminals
- **Default SiteId**: Changed from 1 to 3187 → Rationale: User specified 3187 as standard test site for all queries
- **SalesFact JOIN on PosId AND Pod**: All SalesFact subqueries group by PosId, Pod and join on both → Rationale: Each POS-Pod combination needs its own GST/ProductSales/NonProdSales values, not period totals. Period-level totals were causing negative NetSales (each row got the same total GST value)
- **ProductSales from SalesFact directly**: ProductSales = SUM(NetAmount) WHERE ProductSaleTypeId = 1, NOT NetSales - NonProdSales → Rationale: User corrected - ProductSales comes directly from SalesFact, not calculated from cash drawer values
- **Test queries location**: All test files in `tests/` subfolder within query directory → Rationale: Keep test/diagnostic queries organized in dedicated subfolder, prefix with `test-`

---

## Next Steps

**Currently**: User is testing the query

**Waiting for**:
1. Test results from production data
2. User feedback on any issues or adjustments needed
3. Confirmation that query is working as expected

**After testing passes**:
1. Mark query as COMPLETE
2. GetPodFullName server action integration
3. DBA review - Submit 5 index recommendations for implementation
4. Performance monitoring

---

## Notes for Next Session

- **User snippets provided**: TenderType logic with CASE WHEN pattern - reused in query
- **Pod handling**: Type column returns Pod value, needs GetPodFullName server action in OutSystems
- **Images not needed**: User confirmed no need to save images to table docs
- **Session tracking**: Context file designed for anyone to continue work
- **Pending equations**: Don't guess - wait for user confirmation
- **Table naming**: Always use {TableName}, NEVER [dbo].[TableName] - OutSystems convention
- **Index docs**: Only in README.md, not in query.sql files
- **SQL Server**: Target 2014+ compatibility for all queries
- **DB optimization**: Minimize hits to database, use single query with JOINs/subqueries
- **Latest commit**: 96f0bdc - Fixed GROUP BY clause error, added DB optimization guidelines
- **Current status**: User is testing the query - waiting for feedback before marking as complete

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
   - Query is COMPLETE - all equations implemented
   - DECLARE parameters at top (@SiteId, @Date)

3. **Status**:
   - ✅ All sales calculations complete (GrossSales, NetSales, ProductSales)
   - ✅ GROUP BY clause fixed
   - ✅ DB optimization guidelines added
   - 🧪 **IN TESTING** - User is actively testing with production data

4. **Next actions**:
   - Wait for test results and user feedback
   - Address any issues found during testing
   - Mark as complete when user confirms it's working

---

## Repository State

**Files created this session**:
- `database-context/tables/SalesFact/README.md`
- `database-context/tables/SWCPosTerminal/README.md`
- `database-context/tables/SWCCashDrawerTender/README.md`
- `database-context/tables/SWCCashDrawer/README.md`
- `database-context/tables/SWCPeriod/README.md` (added later)
- `queries/reports/product-sales-by-drawer/query.sql`
- `queries/reports/product-sales-by-drawer/README.md`
- `queries/reports/product-sales-by-drawer/metadata.json`
- `queries/reports/product-sales-by-drawer/WORKFLOW.md`
- `.claude/sessions/product-sales-by-drawer-context.md` (this file)

**Files updated**:
- `.claude/claude.md` - Added DECLARE pattern rule, query naming rule, table doc guidelines, index recommendations workflow, SQL Server 2014+ target, {TableName} naming convention
- `README.md` - Optimized for Claude auto-load workflow
- `queries/reports/product-sales-by-drawer/query.sql` - Updated SalesFact usage, changed to {TableName} format, removed inline index comments, added SQL 2014+ compatibility header
- `queries/reports/product-sales-by-drawer/README.md` - Added SQL Server 2014+ note, comprehensive index recommendations
- `queries/reports/product-sales-by-drawer/metadata.json` - Added sql_server_version field
- `database-context/tables/SalesFact/README.md` - Added proper join patterns with SWCPeriodId, updated to {TableName} format
- All table docs - Updated example queries to use {TableName} format

**Git Commits**:
1. `09ace3a` - Initial commit: Repository setup with initial query
2. `0845458` - SQL 2014 compatible, SWCPeriod integration, index recommendations
3. `50611d9` - OutSystems {TableName} format throughout
4. `2442a5b` - Session context update
5. `5c3367d` - Session context must be updated REGULARLY (claude.md update)
6. `c8c6393` - COMPLETE: All sales equations implemented
7. `96f0bdc` - Fix GROUP BY clause error, add DB optimization guidelines

**Current State**: Query development complete, IN TESTING - waiting for user feedback
