# Stock Transfer Detail

**Story**: 1.3.2 - View Transfer Detail (Pending)
**Category**: Stock
**Created**: 2026-03-31

## Purpose

Two queries for the Transfer Detail screen:
1. **Header query** (`query-header.sql`) — Transfer metadata, approval status panel, totals
2. **Lines query** (`query-lines.sql`) — Line items with quantities and pricing

Works for both pending and completed transfers — the screen displays differently based on `IsApproved`.

## Queries

### query-header.sql

Returns a single row with transfer header info.

**Input Parameters:**

| Parameter | Type | Expand Inline | Description |
|-----------|------|---------------|-------------|
| `@StockMovementId` | BIGINT | NO | The transfer ID to view |

**Output Columns:**

| Column | Type | Description |
|--------|------|-------------|
| `StockMovementId` | LongInteger | Transfer ID (Invoice ID in UI) |
| `ApprovedDate` | Date | Business date set on approval (null if pending) |
| `CreatedAt` | Date | When the transfer was created |
| `FromSiteId` | LongInteger | Sending site ID |
| `ToSiteId` | LongInteger | Receiving site ID |
| `FromSiteName` | Text | Sending site display name |
| `ToSiteName` | Text | Receiving site display name |
| `IsApproved` | Boolean | false = Pending, true = Completed |
| `SenderApprovedByName` | Text | Creator name (sender auto-approves at creation) |
| `SenderApprovedAt` | Date | Creation timestamp (sender approval = creation time) |
| `ReceiverApprovedByName` | Text | Approver name at receiving site (null if pending) |
| `ReceiverApprovedAt` | Date | Approval timestamp (null if pending) |
| `NetAmount` | Decimal | Total ex GST |
| `TaxAmount` | Decimal | GST amount |
| `GrossAmount` | Decimal | Total incl. GST |
| `Comment` | Text | Optional memo |

### query-lines.sql

Returns one row per line item.

**Input Parameters:**

| Parameter | Type | Expand Inline | Description |
|-----------|------|---------------|-------------|
| `@StockMovementId` | BIGINT | NO | The transfer ID to view |

**Output Columns:**

| Column | Type | Description |
|--------|------|-------------|
| `LineId` | LongInteger | Line item ID |
| `PhysicalItemId` | LongInteger | Physical item ID |
| `Code` | Text | Item WRIN/code |
| `Description` | Text | Item description (snapshot from creation) |
| `Cartons` | Integer | Number of cartons |
| `Inners` | Integer | Number of inners |
| `Units` | Integer | Number of loose units |
| `TotalUnits` | Integer | Calculated total unit count |
| `PricePerUnit` | Decimal | Unit price (from BO_RawItemPrice at creation) |
| `Cost` | Decimal | Line total (TotalUnits x PricePerUnit) |

## OutSystems Implementation Notes

### Breadcrumb
`Transfers > [ApprovedDate or CreatedAt]: [FromSiteName] -> [ToSiteName]`

### Approval Status Panel
Two-sided panel showing sender and receiver approval:
- **Sender side**: Always show as approved — use `SenderApprovedByName` + `SenderApprovedAt`
- **Receiver side**: If `IsApproved = true`, show `ReceiverApprovedByName` + `ReceiverApprovedAt`. If false, show "Pending"

### Warning/Info Banners
- If user's site = `ToSiteId` and `IsApproved = false` → Warning: "Your approval is required..."
- If user's site = `FromSiteId` and `IsApproved = false` → Info: "Awaiting [ToSiteName]"

### Approve/Decline Buttons
Show only when: user has StockInvoice_Admin role, user's site = `ToSiteId`, and `IsApproved = false`

### Amounts for Pending
For pending transfers, StockMovement amounts are null. The header query falls back to line item totals with 10% GST.

## Tables Used

- `{Transfer}` — Transfer extension
- `{StockMovement}` — Parent movement
- `{StockMovementLine}` — Line items
- `{Site}` — Site names (x2)
- `{User}` — User names (x2)
- `{PhysicalItem}` — Item code (WrinNumber)

## Files

- `query-header.sql` — Header/approval query
- `query-lines.sql` — Line items query
- `output-structure.json` — OutSystems Output Structure (both queries)
- `tests/test-ssms.sql` — SSMS test version (header only, single SELECT)
