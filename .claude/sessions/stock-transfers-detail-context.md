# Session: Stock Transfers Detail - 2026-03-31

## Original Story/Requirements
**PRD 1.3 - Inter-Store Stock Transfers**, Stories 1.3.2 / 1.3.3 / 1.3.4

- 1.3.2: View Transfer Detail (Pending + Completed)
- 1.3.3: Approve a Transfer
- 1.3.4: Decline a Transfer

## Status
- [X] Complete / [ ] In Progress / [ ] In Testing
- All tested, in peer review
- **2026-04-12**: Cross-tenant user name denormalization ATTEMPTED AND REVERTED — see known issue below

### Approve Verification (2026-04-03)
- Tested with StockMovementId=42, NZ site (15% GST)
- StockMovement: Net=224.52, Tax=33.678, Gross=258.198 ✅
- Transfer: IsApproved=True, ApprovedByUserId=317662 ✅
- Lines: 2 items, total=224.52 (matches SM_NetAmount) ✅
- StockPeriodBalance: 1 of 2 items had LogicalItem mapping
  - Sender (3188): TransferQty=-12 ✅
  - Receiver (3189): TransferQty=+12 ✅
- Items without LogicalItem mapping skipped (expected behavior)

## Queries Created
- `queries/stock/stock-transfers-detail/` - Status: in-testing
  - `query-header.sql` — Transfer metadata, approval panel, amounts, memo. Dynamic GST via @CountryCode
  - `query-lines.sql` — Line items + Total row (IsTotal = 1) via UNION ALL
  - Tables used: Transfer, StockMovement, StockMovementLine, Site, User, PhysicalItem
  - Parameters: @StockMovementId (BIGINT), @CountryCode (VARCHAR, header only)
  - Tests: `tests/test-ssms-header.sql`, `tests/test-ssms-lines.sql`, `tests/test-approve-verify.sql`

## Server Actions Built (Stock_CS)

### DeleteStockTransfer
- **Input**: StockMovementId
- **Flow**: Get lines aggregate → loop delete each line → DeleteTransfer → DeleteStockMovement
- **Status**: Working

### ApproveStockTransfer
- **Input**: StockMovementId, CountryCode
- **Flow**:
  1. Get lines aggregate (GetLines)
  2. For Each loop → sum TotalNetAmount
  3. Assign: GSTRate (AU=0.10, NZ=0.15, Fj=0.15), TaxAmount, GrossAmount
  4. GetTransfer aggregate → Update Transfer (IsApproved=True, ApprovedByUserId, ApprovedAt)
  5. StockMovement aggregate → Update StockMovement (Date=CurrDate(), NetAmount, TaxAmount, GrossAmount)
  6. Assign: FromSiteId = GetTransfer.FromSiteId, ToSiteId = StockMovement.DeliverySiteId
  7. **UpdateStockPeriodBalanceTransfers**(SiteId=FromSiteId, Date=CurrDate()) — existing StockLedger action
  8. **UpdateStockPeriodBalanceTransfers**(SiteId=ToSiteId, Date=CurrDate()) — existing StockLedger action
- **Status**: Working (Transfer + StockMovement updates verified, StockPeriodBalance needs testing with items that have LogicalItem mappings)

## Key Decisions
- **Two queries, one folder**: Header binds to form fields, lines bind to table widget
- **Sender approval = creation**: SenderApprovedByName is the creator, SenderApprovedAt is CreatedAt
- **Pending amounts fallback**: CASE WHEN ISNULL(sm.NetAmount, 0) = 0 → falls back to line totals
- **Dynamic GST**: @CountryCode param → AU=10%, NZ=15%, Fj=15%
- **Site names**: Use `Name` not `DisplayName` (changed across all queries)
- **Lines total row**: UNION ALL with IsTotal=1 identifier, OutSystems uses If widget per row
- **Decline = hard delete**: Lines → Transfer → StockMovement, no balance updates
- **Invoice Number format**: `FromSiteId-XXXXXX` (6-digit zero-padded StockMovementId, e.g., `202-000004`). Computed in SQL, returned as `InvoiceNumber` Text column in both list and detail queries
- **StockPeriodBalance via existing action**: Use `UpdateStockPeriodBalanceTransfers(SiteId, Date)` from StockLedger folder — handles LogicalItem resolution, portions conversion, create-if-missing. Called twice (sender + receiver) instead of custom loop
- **Skip if no LogicalItem**: Items without LogicalItem mapping won't get balance updates (data issue, not code issue)

## 📌 PINNED: StockPeriodBalance — PRD vs Reality (2026-04-02)
**Status**: Resolved — using existing `UpdateStockPeriodBalanceTransfers` action

**PRD says** (simplified): `SiteId + PhysicalItemId + BusinessDate → TransferredQty`
**Actual table**: `StockPeriodId + LogicalItemId → TransferQty (Decimal, in portions)`

**Resolution**: Instead of custom loop with PhysicalItem→LogicalItem resolution, we use the existing
`UpdateStockPeriodBalanceTransfers(SiteId, Date)` action from the StockLedger folder which already
handles all the complexity (LogicalItem mapping, portions, StockPeriod lookup, create-if-missing).

**Note**: Test items (Toy Aladdin Jasmin, BEEF PATTIES, MILK GF TRIM) don't have LogicalItem mappings,
so balance updates won't show for those. Real items should have mappings.

## Frontend — Detail Screen
- **Block**: `StockTransferDetailsBlock`
- **Input params**: StockMovementId, FromSiteId, FromSiteName, ToSiteId, ToSiteName, TransferDate
- **If widget**: `IsApproved` → True (completed view) / False (pending view)
- **False (pending)**: Header bar, alert banner, approval panel, line items datagrid, memo, Decline + Accept buttons
- **True (completed)**: Transfer report layout (TBD)

### Pending View Widget Tree
```
Container (class: "transfer-detail-pending")
├─ Container (class: "transfer-detail-header-bar")
│   ├─ Container (class: "transfer-detail-header-left")
│   │   ├─ Expression: "Invoice #" + StockMovementId
│   │   └─ Expression (class: "header-meta"): FormatDateTime(TransferDate, "dd MMM yyyy") + " · " + FromSiteName + " → " + ToSiteName
│   └─ StatusBadge: "AWAITING YOUR APPROVAL"
├─ AlertBanner (existing block): warning, visible if UserSiteId = ToSiteId
├─ Container (class: "approval-panel")
│   ├─ Approval card: FromSiteName (OUTGOING) — ● Approved — name + date
│   └─ Approval card: ToSiteName (INCOMING) — ● Not yet reviewed
├─ Line items datagrid (If widget per row: IsTotal = 1)
├─ Memo section (visible if Comment <> "")
└─ Action buttons: Decline + Accept (visible if UserSiteId = ToSiteId AND admin)
```

### Datagrid Column Expressions
- **Code**: If(IsTotal=1, "", Code)
- **Description**: If(IsTotal=1, "Total ex GST", Description) — bold + right-aligned for total
- **Cartons/Inners/Units**: If(IsTotal=1, "", If(value=0, "—", value))
- **Total Units**: If(IsTotal=1, "", TotalUnits)
- **Price/Unit**: If(IsTotal=1, "", "$" + FormatDecimal(PricePerUnit, 2, ".", ","))
- **Cost**: "$" + FormatDecimal(Cost, 2, ".", ",") — bold blue for total row

### CSS
```css
.transfer-detail-header-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
    font-size: 15px;
    font-weight: 500;
    gap: 16px;
}
.transfer-detail-header-left {
    display: flex;
    align-items: center;
    gap: 12px;
    white-space: nowrap;
    flex-shrink: 0;
}
.invoice-number { white-space: nowrap; font-size: 15px; font-weight: 500; }
.header-meta { font-size: 13px; color: #666; font-weight: 400; white-space: nowrap; }
.approval-panel { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 20px; }
.approval-card { padding: 16px; border: 1px solid #e0e0e0; border-radius: 6px; }
.approval-card-title { font-size: 13px; font-weight: 700; text-transform: uppercase; margin-bottom: 8px; }
.approval-status { display: flex; align-items: center; gap: 8px; font-size: 14px; font-weight: 600; margin-bottom: 4px; }
.approval-status.approved { color: #2E7D32; }
.approval-status.pending { color: #F9A825; }
.approval-meta { font-size: 12px; color: #888; }
.memo-section { padding: 12px 16px; background-color: #f8f9fa; border: 1px solid #e0e0e0; border-radius: 6px; margin: 16px 0; font-size: 13px; color: #555; }
.action-buttons { display: flex; justify-content: flex-end; gap: 12px; padding: 16px 0; }
.btn-decline { background-color: #dc3545; color: #fff; border: none; padding: 10px 24px; font-weight: 600; font-size: 14px; border-radius: 4px; }
.btn-approve { background-color: #28a745; color: #fff; border: none; padding: 10px 24px; font-weight: 600; font-size: 14px; border-radius: 4px; }
.total-row-highlight { background-color: #f5f5f5; border-top: 2px solid #333; }
```

## Completed View (True branch) — DONE ✅
Built and verified (2026-04-03). Updated 2026-04-09: left-aligned report header, Invoice date = ReceiverApprovedAt, Price/Unit 2dp.

### Widget Tree
```
If (IsApproved = True)
└─ Container (class: "detail-card")
    ├─ Container (class: "report-header")
    │   ├─ Expression: "Transfer Report"
    │   └─ Expression: "Invoice: " + StockMovementId
    ├─ Container (class: "report-meta-grid")
    │   ├─ Container → Label "Supplied by:" + Expression: FromSiteName
    │   ├─ Container → Label "Invoice date:" + Expression: FormatDateTime(ReceiverApprovedAt, "d/MM/yyyy")
    │   ├─ Container → Label "Supplied To:" + Expression: ToSiteName
    │   └─ Container → Label "Status:" + Expression: "Complete · read-only" (class: "badge-complete")
    ├─ [Existing Datagrid — query-lines.sql, same as pending view]
    ├─ Container (class: "memo-box", visible: Comment <> "")
    │   └─ Expression: "Memo: " + Comment
    ├─ Expression: "Digital approval record" (class: "digital-approval-title")
    └─ Container (class: "appr-grid")
        ├─ Container (class: "appr-side")
        │   ├─ Expression (class: "appr-title"): FromSiteName + " (outgoing)"
        │   ├─ Container (class: "appr-row") → Container (class: "dot dot-ok") + Expression: SenderApprovedByName
        │   └─ Expression (class: "appr-meta"): FormatDateTime(SenderApprovedAt, "d MMM yyyy")
        └─ Container (class: "appr-side")
            ├─ Expression (class: "appr-title"): ToSiteName + " (incoming)"
            ├─ Container (class: "appr-row") → Container (class: "dot dot-ok") + Expression: ReceiverApprovedByName
            └─ Expression (class: "appr-meta"): FormatDateTime(ReceiverApprovedAt, "d MMM yyyy")
```

### CSS (completed view classes)
```css
.detail-card { background:#fff; border:1px solid #e3e6e8; border-radius:6px; padding:20px 24px; margin-bottom:16px; }
.report-header { text-align:left; padding-bottom:14px; margin-bottom:16px; border-bottom:1px solid #e3e6e8; }
.report-header span { display:block; }
.report-header span:first-child { font-size:20px; font-weight:700; margin-bottom:2px; }
.report-header span:last-child { font-size:14px; color:#888; margin-top:0; }
.report-meta-grid { display:grid; grid-template-columns:1fr 1fr; gap:8px; font-size:14px; margin-bottom:20px; }
.report-meta-grid .label { font-weight:400; color:#888; }
.badge-complete { display:inline-block; background:#d4edda; color:#155724; border:2px solid #81c784; padding:6px 16px; border-radius:20px; font-size:12px; font-weight:700; text-transform:uppercase; letter-spacing:0.05em; }
.memo-box { border:1px solid #e3e6e8; border-radius:4px; padding:10px 14px; font-size:14px; color:#666; margin-bottom:16px; }
.digital-approval-title { font-size:13px; font-weight:600; color:#888; text-transform:uppercase; letter-spacing:0.04em; margin-bottom:12px; }
.appr-grid { display:grid; grid-template-columns:1fr 1fr; gap:12px; margin-bottom:16px; }
.appr-side { background:#f8f9fb; border:1px solid #e3e6e8; border-radius:6px; padding:12px 14px; }
.appr-title { font-size:13px; font-weight:600; color:#666; text-transform:uppercase; letter-spacing:0.04em; margin-bottom:6px; }
.appr-row { display:flex; align-items:center; gap:8px; font-size:14px; font-weight:500; }
.appr-meta { font-size:13px; color:#888; margin-top:4px; }
.dot { width:10px; height:10px; border-radius:50%; flex-shrink:0; }
.dot-ok { background:#28a745; }
```

## Main List Screen (2026-04-07)
- Two separate datagrids (Pending / Completed) wrapped in If on ViewType
- **Pending columns**: Direction badge, Invoice, Date, From, To, Lines, Ex GST, Total (incl. GST), Status
- **Completed columns**: Direction badge, Invoice, Date, From, To, Lines, Ex GST, GST, Total, Approved by (out), Approved by (in)
- **Direction badge**: `If(ToSiteId = SelectedSiteId, "↓ In", "↑ Out")` — hidden when no specific site selected
- **Status badge**: `If(ToSiteId = SelectedSiteId, "Awaiting your approval", "Awaiting " + ToSiteName)`
- **StatusBadge block CSS classes**: `.pending` (red), `.approved` (green), `.info` (blue), `.awaiting` (blue outline)
- **Notification bubble**: `TransfersNotifBlock` — counts pending transfers where `DeliverySiteId = SelectedSiteId`, updates on site change
- **Store filter**: `@FilterSiteId` — filters on both FromSiteId and ToSiteId (0 = all)
- **Role**: `StockInvoice_Admin` required for Create, Approve, Decline. View is open to all with site access.

## Changes (2026-04-12) — Cross-Tenant User Name Denormalization ATTEMPTED AND REVERTED

### Problem Discovered
After cross-tenant favourites shipped (FromSiteName/ToSiteName denormalization), testing revealed the **Receiver Approved By** name was blank when viewing a transfer approved by another tenant. `{User}` is tenant-filtered by OutSystems at the Advanced SQL runtime layer — even though the underlying `User` DB table is physically shared across tenants. Sandbox does NOT apply this filter (misleading — sandbox showed the name, production returned NULL).

### Attempted Solution — Denormalize at write time
- **`StockMovement.CreatedByUserName`** — snapshot written at transfer creation
- **`Transfer.ApprovedByUserName`** — snapshot written at approval
- Queries read from these columns directly, no `{User}` join

**Detail screen worked** ✅ — Transfer 74 showed both Mana and Te Awamutu names correctly.

### Then the list query broke ❌
After applying the same denormalization pattern to `stock-transfers-list/query.sql`, OutSystems runtime started throwing:
```
Database returned the following error:
Error in advanced query TransfersListSQL: Input string was not in a correct format.
```

**Diagnostics tried** (none fixed it):
- ✅ Republished all modules (SL_CS, CommonFunctions_Lib, consumer modules) — no change
- ✅ Refreshed Output Structure on Advanced SQL block — no change
- ✅ Verified entity column types are Text (confirmed correct by user)
- ✅ Expanded entity column length from 50 → 256 — no change
- ✅ SSMS test-ssms.sql runs cleanly via sandbox — query SQL itself is valid
- ✅ Output column order/names/types in SELECT match Output Structure exactly (diff verified)
- ❌ Error persists **only in OutSystems runtime**, only on the list query

**Root cause: UNKNOWN.** Error message suggests `.NET` `Convert` failing on a string→number parse, but no number columns were touched in the diff. Detail query uses the exact same pattern (same two columns, same Text type) and works fine. Something about the list query's OutSystems runtime mapping is rejecting the denormalized columns, but we couldn't identify what.

### Revert Decision
Reverted both queries back to using `{User}` joins to unblock the user. The detail screen loses cross-tenant receiver name visibility again (known limitation), but the list screen works and everything is consistent.

### Files Reverted
- `queries/stock/stock-transfers-list/query.sql` — restored `{User}` joins + `t.ApprovedByUserId` / `sm.CreatedBy` in TransferData CTE
- `queries/stock/stock-transfers-list/tests/test-ssms.sql` — mirrored
- `queries/stock/stock-transfers-detail/query-header.sql` — restored `{User}` joins
- `queries/stock/stock-transfers-detail/tests/test-ssms-header.sql` — mirrored

Both queries now carry a ⚠️ KNOWN LIMITATION comment at the join site pointing back to this session context.

### Files KEPT (still reflect the denormalization pattern)
These are still valid documentation and don't affect query execution. They describe the pattern that **should** work and that we'll revisit:
- `database-context/tables/Transfer/README.md` — Cross-Tenant Notes section + `ApprovedByUserName` column docs
- `database-context/tables/StockMovement/README.md` — `CreatedByUserName` column docs
- `database-context/tables/User/README.md` — critical warning about `{User}` tenant-filter
- Auto-memory `MEMORY.md` — cross-tenant quirks saved for future sessions

### OutSystems-side state
The user decided to keep the entity columns and server-action writes in place (already deployed). They're populated via the Create/Approve actions and backfilled. They just aren't read by any query anymore. When we figure out what OutSystems is choking on, we can flip the queries back over without touching the entity or data again.

### Known Issue — Open
- **Detail screen**: Receiver name blank for cross-tenant approvals (same as original state before any of this work)
- **List screen**: Works, but `CreatedByName`/`ApprovedByName` will be blank for cross-tenant users in the Completed view
- **Next investigation angles** for future session:
  - Does the list block sit in a module with a different User provider than the detail block?
  - Try pasting the new query text directly into OutSystems Service Studio (bypass the refresh-output-structure flow) and test immediately
  - Compare the exact list output structure field types byte-by-byte against a fresh regen
  - Try running the list with denormalized columns AND `{User}` joins simultaneously to see if OutSystems is mapping the wrong column to the wrong structure field
  - Check whether `TransferListApprovedExport` structure (seen in screenshot) has different field types that might be used somewhere

---

## Changes (2026-04-09)
- **Pending view header**: Fixed wrapping — added `flex-shrink: 0`, `white-space: nowrap`, `gap` to header bar
- **Invoice number**: Added `.invoice-number` class with `white-space: nowrap`
- **Alert block**: Created `AlertNoWrap` block with `.alert-nowrap-style/icon/title` classes (single-line, icon centered)
- **Completed view**: Left-aligned report header, tightened invoice number gap
- **Invoice date**: Changed from `CreatedAt` to `ReceiverApprovedAt` (actual approval date)
- **Price/Unit**: Changed from 5dp to 2dp
- **Transfer entity**: Changed `ApprovedAt` from Text to DateTime

## Next Steps
1. ~~Test approve with items that have LogicalItem mappings (verify StockPeriodBalance)~~ ✅ Done
2. ~~Build completed (True) view widget tree~~ ✅ Done
3. ~~Build main list screen frontend~~ ✅ Done
4. ~~Add InvoiceNumber format (SiteId-XXXXXX) to list + detail queries~~ ✅ Done
5. ~~End-to-end testing~~ ✅ Done
6. ~~CSS fixes + Invoice date + Price/Unit 2dp~~ ✅ Done (2026-04-09)

## Quick Resume
1. Read this context
2. All queries done: list (query.sql), detail header (query-header.sql), detail lines (query-lines.sql)
3. All server actions done: ApproveStockTransfer, DeleteStockTransfer
4. All frontend views done: Pending list, Completed list, Pending detail, Completed detail
5. Continue from: End-to-end testing
