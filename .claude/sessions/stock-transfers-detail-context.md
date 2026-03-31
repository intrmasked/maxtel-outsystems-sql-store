# Session: Stock Transfers Detail - 2026-03-31

## Original Story/Requirements
**PRD 1.3 - Inter-Store Stock Transfers**, Story 1.3.2: View Transfer Detail (Pending)

View full details of a pending (or completed) transfer — header with approval status panel, line items table, memo, and action buttons.

## Status
- [ ] Complete / [ ] In Progress / [X] In Testing
- Current step: Queries written and verified (run successfully, no data yet)
- Incomplete items: Real data testing once Create Transfer screen is built
- Git commit: `9148445`

## Queries Created
- `queries/stock/stock-transfers-detail/` - Status: in-testing
  - `query-header.sql` — Transfer metadata, approval panel, amounts, memo
  - `query-lines.sql` — Line items with code, quantities, pricing
  - Tables used: Transfer, StockMovement, StockMovementLine, Site, User, PhysicalItem
  - Parameters: @StockMovementId (BIGINT)

## Key Decisions
- **Two queries, one folder**: Header binds to form fields, lines bind to table widget in OutSystems
- **Sender approval = creation**: SenderApprovedByName is the creator, SenderApprovedAt is CreatedAt
- **Pending amounts from lines**: Falls back to SUM of StockMovementLine.NetAmount with 10% GST when StockMovement amounts are null
- **Item code from PhysicalItem.WrinNumber**: Joined via StockMovementLine.PhysicalItemId

## Quick Resume
1. Read: `queries/stock/stock-transfers-detail/README.md`
2. Header: `queries/stock/stock-transfers-detail/query-header.sql`
3. Lines: `queries/stock/stock-transfers-detail/query-lines.sql`
