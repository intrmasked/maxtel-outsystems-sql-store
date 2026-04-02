# Session: Stock Transfers Detail - 2026-03-31

## Original Story/Requirements
**PRD 1.3 - Inter-Store Stock Transfers**, Stories 1.3.2 / 1.3.3 / 1.3.4

- 1.3.2: View Transfer Detail (Pending + Completed)
- 1.3.3: Approve a Transfer
- 1.3.4: Decline a Transfer

## Status
- [ ] Complete / [X] In Progress / [ ] In Testing
- Current step: Approve + Decline server actions complete, pending view frontend mostly built
- Remaining: Completed (True) view widget tree, end-to-end testing with StockPeriodBalance verification

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
- **Invoice ID**: No separate field in DB — using StockMovementId directly
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
- **Price/Unit**: If(IsTotal=1, "", "$" + FormatDecimal(PricePerUnit, 5, ".", ","))
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
}
.header-meta { font-size: 13px; color: #666; font-weight: 400; }
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

## Completed View (True branch) — TBD
Transfer report layout:
- "Transfer report" title centered, Invoice number
- Info row: Supplied by / Supplied to / Invoice date / Status badge (COMPLETE · READ-ONLY)
- Line items table + Total ex GST
- Memo
- DIGITAL APPROVAL RECORD section
- Two approval cards (both green, with dates)
- No action buttons

## Next Steps
1. Test approve with items that have LogicalItem mappings (verify StockPeriodBalance)
2. Build completed (True) view widget tree
3. End-to-end testing
4. Commit and update session

## Quick Resume
1. Read this context
2. Approve + Decline actions are done in Stock_CS
3. Pending view frontend is mostly done
4. Continue from: Completed (True) view + end-to-end testing
