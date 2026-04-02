# Session: Stock Transfers Detail - 2026-03-31

## Original Story/Requirements
**PRD 1.3 - Inter-Store Stock Transfers**, Stories 1.3.2 / 1.3.3 / 1.3.4

- 1.3.2: View Transfer Detail (Pending + Completed)
- 1.3.3: Approve a Transfer
- 1.3.4: Decline a Transfer

## Status
- [ ] Complete / [X] In Progress / [ ] Needs Review
- Current step: Detail queries tested with real data, decline action built, approve action in progress (steps 1-6 done, step 7 StockPeriodBalance pending)
- Frontend: Pending view (False branch) being built with widget tree + CSS

## Queries Created
- `queries/stock/stock-transfers-detail/` - Status: in-testing
  - `query-header.sql` — Transfer metadata, approval panel, amounts, memo. Dynamic GST via @CountryCode
  - `query-lines.sql` — Line items + Total row (IsTotal = 1) via UNION ALL
  - Tables used: Transfer, StockMovement, StockMovementLine, Site, User, PhysicalItem
  - Parameters: @StockMovementId (BIGINT), @CountryCode (VARCHAR, header only)
  - Tests: `tests/test-ssms-header.sql`, `tests/test-ssms-lines.sql` (split from single file)

## Server Actions Built (Stock_CS)
- **DeclineTransfer** — Input: StockMovementId. Deletes: StockMovementLines (loop) → Transfer → StockMovement. Working.
- **ApproveTransfer** — Input: StockMovementId, CountryCode. Steps 1-6 done:
  1. Get lines aggregate
  2. Loop to sum TotalNetAmount
  3. Calculate GST (AU=10%, NZ=15%, Fj=15%)
  4. Update Transfer (IsApproved, ApprovedByUserId, ApprovedAt)
  5. Update StockMovement (Date, NetAmount, TaxAmount, GrossAmount)
  6. **Step 7 pending**: StockPeriodBalance updates

## Key Decisions
- **Two queries, one folder**: Header binds to form fields, lines bind to table widget
- **Sender approval = creation**: SenderApprovedByName is the creator, SenderApprovedAt is CreatedAt
- **Pending amounts fallback**: CASE WHEN ISNULL(sm.NetAmount, 0) = 0 → falls back to line totals
- **Dynamic GST**: @CountryCode param → AU=10%, NZ=15%, Fj=15%
- **Site names**: Use `Name` not `DisplayName` (changed across all queries)
- **Lines total row**: UNION ALL with IsTotal=1 identifier, OutSystems uses If widget per row
- **Decline = hard delete**: Lines → Transfer → StockMovement, no balance updates
- **Invoice ID**: No separate field in DB — using StockMovementId directly

## 📌 PINNED: StockPeriodBalance Mismatch (2026-04-02)
**Status**: Needs resolution for Approve step 7

**PRD says** (simplified): `SiteId + PhysicalItemId + BusinessDate → TransferredQty`
**Actual table**: `StockPeriodId + LogicalItemId → TransferQty (Decimal, in portions)`

**To update StockPeriodBalance on approve:**
1. Resolve PhysicalItemId → LogicalItemId (via `LogicalItem.DefaultPhysicalItemId`)
2. Find StockPeriodId from `StockPeriod` WHERE `SiteId + Date`
3. Convert QtyTotal to portions (× `PortionsPerUnit`)
4. Update `TransferQty` on the balance row

## Frontend — Detail Screen
- **Block**: `StockTransferDetailsBlock`
- **If widget**: `IsApproved` → True (completed view) / False (pending view)
- **False (pending)**: Header bar, alert banner, approval panel, line items datagrid, memo, action buttons
- **True (completed)**: Transfer report layout (TBD)

### CSS Classes
```css
.transfer-detail-header-bar — flex, space-between, no background
.header-meta — 13px, #666
.approval-panel — 2-col grid
.approval-card — bordered card
.approval-card-title — uppercase, bold
.approval-status.approved — green
.approval-status.pending — yellow
.approval-meta — 12px, #888
.memo-section — light bg, bordered
.action-buttons — flex end, gap 12px
.btn-decline — red bg
.btn-approve — green bg
```

## Next Steps
1. Complete StockPeriodBalance update logic in ApproveTransfer (step 7)
2. Finish pending view frontend (datagrid expressions, action button wiring)
3. Build completed (True) view widget tree
4. Test full approve + decline flow end-to-end

## Quick Resume
1. Read this context
2. Header query: `queries/stock/stock-transfers-detail/query-header.sql`
3. Lines query: `queries/stock/stock-transfers-detail/query-lines.sql`
4. Continue from: StockPeriodBalance update logic + frontend wiring
