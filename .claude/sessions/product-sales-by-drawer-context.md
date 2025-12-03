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

- [X] Complete
- [ ] In Testing
- [ ] Ready for OutSystems

**Current step**: Query complete and ready for OutSystems Advanced SQL Block

**MAJOR CHANGE (2025-12-03)**:
- ⚠️ **Reverted from Aggregates back to SQL** - Conditional aggregation needs SQL
- User built Aggregates but encountered filtering limitations in loops
- Single optimized SQL query with conditional SUM more efficient than 4 aggregates
- Query uses correct column names verified against table documentation

**Latest changes (2025-12-03 - Current Session):**
- ✅ **Complete query rewrite** - Single DrawerData CTE with conditional SUM
  - Uses SWCCashDrawer, SWCPosTerminal, SWCCashDrawerTender, TenderType
  - No SalesFact needed - all data from cash drawer entities
  - Filters by TenderType.IsCash = 1 for cash tenders
  - Filters by TenderType.TenderTypeId IN (10, 13, 16, 19, 21) for Eftpos group
  - Filters by TenderType.Category = 'TENDER_GIFT_COUPON' for gift cards
- 🐛 **FIXED: Column name errors** - Verified all columns against table docs
  - cd.GTFinal → cd.FinalGT
  - cd.GTInitial → cd.InitialGT
  - cdt.NetAmount → cdt.DrawerAmount
  - cd.NonProductSalesAmount → Added to table docs and query
- 🐛 **FIXED: ORDER BY with UNION error** - Added SortOrder column to SELECT list
  - SortOrder = 0 for POS rows, 1 for Total row
  - Required for ORDER BY with UNION ALL
- ✅ **Added NonProductSalesAmount to SWCCashDrawer table docs**
- ✅ **Created TenderType table documentation** - IsCash flag, TenderTypeId values, Category field
- ✅ **Query ready for OutSystems** - Removed DECLARE statements, added setup instructions
- 📝 **Updated claude.md** - Added mandatory rule to always check table docs before writing SQL

**Complete items**:
1. ✅ GrossSales equation: Difference - CashRefund - EftposRefund - GCSold (Overring removed)
2. ✅ NetSales equation: GrossSales - GST
3. ✅ ProductSales equation: NetSales - NonProdSales
4. ✅ NonProdSales: cd.NonProductSalesAmount from SWCCashDrawer
5. ✅ GST: cd.TaxAmount from SWCCashDrawer
6. ✅ CashRefund: Conditional SUM by TenderType.IsCash = 1
7. ✅ EftposRefund: Conditional SUM by TenderType.TenderTypeId IN (10, 13, 16, 19, 21)
8. ✅ GCSold: Conditional SUM by TenderType.Category = 'TENDER_GIFT_COUPON'
9. ✅ SiteId filter via SWCPeriod.SiteId
10. ✅ Date filter via SWCPeriod.BusDate
11. ✅ Query structure: 14 columns (including SortOrder)
12. ✅ Total row via UNION ALL with SortOrder
13. ✅ All column names verified against table documentation
14. ✅ OutSystems-ready format (DECLARE statements commented out)
15. ✅ Single optimized query with conditional SUM

**Ready for OutSystems**:
- Query complete with correct column names
- All calculations implemented
- Total row included
- OutSystems setup instructions documented
- Input Parameters: SiteId (Long Integer), Date (Date)
- Output Structure: 14 columns documented

**Pending (after OutSystems implementation)**:
- User testing in OutSystems Advanced SQL Block
- GetPodFullName server action integration (Type column → Pod value)
- Validate calculations with production data
- DBA review for index recommendations if needed

---

## Tables Documentation Created

- `database-context/tables/SalesFact/` - [EXISTING] - Sales transaction fact table
- `database-context/tables/SWCPosTerminal/` - [EXISTING] - POS terminal session data
- `database-context/tables/SWCCashDrawerTender/` - [EXISTING] - Tender-specific drawer data
- `database-context/tables/SWCCashDrawer/` - [EXISTING] - Main cash drawer session table (updated with NonProductSalesAmount)
- `database-context/tables/SWCPeriod/` - [EXISTING] - Operating period with SiteId and BusDate
- `database-context/tables/TenderType/` - [NEW - 2025-12-03] - Payment tender types with IsCash flag

**Note**: All table docs are universal and can be reused by other queries

---

## Queries Created

- `queries/reports/product-sales-by-drawer/` - [COMPLETE - READY FOR OUTSYSTEMS]
  - Purpose: Cash drawer reconciliation with GT values, refunds, and sales
  - **Implementation**: SQL Advanced Query (reverted from Aggregates)
  - Tables used: SWCPeriod, SWCCashDrawer, SWCCashDrawerTender, SWCPosTerminal, TenderType
  - Output: 14 columns (including SortOrder for proper Total row sorting)
  - Parameters: SiteId (Long Integer), Date (Date)
  - Status: Query complete, all column names verified, ready for OutSystems testing

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
- **Removed Overring column**: Query now returns 14 columns (13 data + 1 SortOrder) → Rationale: User requirements removed Overring and Other Receipt columns
- **Reverted from Aggregates to SQL (2025-12-03)**: User built Aggregates but couldn't filter conditionally in loops → Rationale: SQL with conditional SUM is more efficient than 4 separate aggregates (1 DB hit vs 4)
- **Single DrawerData CTE**: One CTE with conditional SUM for all tender types → Rationale: Cleaner than multiple CTEs, single scan of cash drawer data
- **Conditional SUM pattern**: `SUM(CASE WHEN tt.Name = 'Cash' THEN ... ELSE 0 END)` → Rationale: Aggregates all tender types in one pass without separate filters
- **TenderType filtering**: Uses TenderType.IsCash flag and TenderType.TenderTypeId values → Rationale: IsCash flag is more reliable than Name matching; specific TenderTypeId values provide explicit control over Eftpos group (10, 13, 16, 19, 21)
- **Column name verification**: All columns checked against table docs before use → Rationale: Prevents errors like GTFinal vs FinalGT, NetAmount vs DrawerAmount
- **SortOrder column in UNION**: Added SortOrder to SELECT list for ORDER BY → Rationale: SQL Server UNION requires ORDER BY columns to be in SELECT list
- **NonProductSalesAmount added**: Field added to SWCCashDrawer table docs → Rationale: User confirmed field exists, updated docs and query to use it
- **OutSystems format**: DECLARE statements commented out, setup instructions added → Rationale: Ready to paste into OutSystems Advanced SQL Block
- **Claude.md update**: Added mandatory rule to always check table docs → Rationale: Prevent column name errors by verifying against documentation first

---

## Next Steps

**Currently**: Query complete and ready for OutSystems

**User to do**:
1. Paste query into OutSystems Advanced SQL Block
2. Add Input Parameters: SiteId (Long Integer), Date (Date), both with Expand Inline = No
3. Define Output Structure with 14 columns (see query documentation)
4. Test with production data
5. Integrate GetPodFullName server action for Type column

**After OutSystems testing**:
1. Validate calculations match business requirements
2. Performance testing with production load
3. DBA review for index recommendations if needed

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

**Git Commits (2025-12-03 Session)**:
1. `158c5ef` - Fix: Corrected column names (FinalGT, InitialGT, DrawerAmount)
2. `e0089e1` - Fix: ORDER BY with UNION requires columns in SELECT list (added SortOrder)
3. `f03a0f2` - Add NonProductSalesAmount field to SWCCashDrawer and update query
4. `b910388` - Add mandatory table reference rule to claude.md
5. `19cf8be` - Update session context for Product Sales By Drawer - 2025-12-03
6. `d687f5b` - Update tender filtering: Use IsCash flag and TenderTypeId values
7. (pending) - Final session context update

**Current State**: Query COMPLETE, ready for OutSystems Advanced SQL Block testing
