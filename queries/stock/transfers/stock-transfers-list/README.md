# Stock Transfers List

**Story**: 1.3.1 - View Transfer List
**Category**: Stock
**Created**: 2026-03-31

## Purpose

Returns a list of inter-store stock transfers for the Pending or Completed view. Supports:
- Filtering by user's accessible sites (as sender or receiver)
- Pending vs Completed toggle via `@ViewType`
- Optional counterpart store filter
- Optional date range filter (Completed view only)

The query returns all data needed for OutSystems to render:
- **Direction indicator** (In/Out) — determined in OutSystems by comparing `FromSiteId`/`ToSiteId` against the viewing user's current site
- **Status badge** — determined in OutSystems from `IsApproved` + site context
- **Pending columns**: StockMovementId, FromSiteName, ToSiteName, CreatedAt, LineCount, ExGST, Total
- **Completed columns**: All pending columns + ApprovedDate, GST, CreatedByName, ApprovedByName, ApprovedAt

## Input Parameters

| Parameter | Type | Expand Inline | Description |
|-----------|------|---------------|-------------|
| `@SiteIds` | VARCHAR | YES | Comma-separated Site IDs the user has access to |
| `@ViewType` | VARCHAR(1) | NO | `'P'` = Pending, `'C'` = Completed |
| `@FilterSiteId` | BIGINT | NO | Filter to a specific counterpart site. `0` = all sites |
| `@StartDate` | DATE | NO | Start date filter (Completed view only). `NULL` = no filter |
| `@EndDate` | DATE | NO | End date filter (Completed view only). `NULL` = no filter |

## Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `StockMovementId` | LongInteger | Transfer ID (used as Invoice ID in UI) |
| `FromSiteId` | LongInteger | Sending site ID (for direction logic in OutSystems) |
| `ToSiteId` | LongInteger | Receiving site ID (for direction logic in OutSystems) |
| `FromSiteName` | Text | Sending site display name |
| `ToSiteName` | Text | Receiving site display name |
| `CreatedAt` | Date | When the transfer was created |
| `ApprovedDate` | Date | Business date set on approval (null for pending) |
| `LineCount` | Integer | Number of line items |
| `ExGST` | Decimal | Amount excluding GST |
| `GST` | Decimal | GST amount |
| `Total` | Decimal | Amount including GST |
| `IsApproved` | Boolean | false = Pending, true = Completed |
| `CreatedByName` | Text | Name of user who created the transfer |
| `ApprovedByName` | Text | Name of user who approved (null for pending) |
| `ApprovedAt` | Date | Approval timestamp (null for pending) |
| `Comment` | Text | Optional memo |

## OutSystems Implementation Notes

### Direction Indicator
Determined in OutSystems (not SQL) by comparing the viewing user's current site against `FromSiteId`/`ToSiteId`:
- If user's site = `FromSiteId` → Show "Out" (orange badge)
- If user's site = `ToSiteId` → Show "In" (blue badge)

### Status Badge (Pending View)
Determined in OutSystems from `IsApproved` + site context:
- If user's site = `ToSiteId` and `IsApproved = false` → "Awaiting your approval" (red)
- If user's site = `FromSiteId` and `IsApproved = false` → "Awaiting [ToSiteName]" (blue)

### Amounts for Pending Transfers
For pending transfers, `NetAmount`/`TaxAmount`/`GrossAmount` on StockMovement are null (set on approval). The query calculates amounts from line items instead using a 10% GST rate.

## Tables Used

- `{Transfer}` — Transfer extension record
- `{StockMovement}` — Parent movement record
- `{StockMovementLine}` — Line items (for count + amount aggregation)
- `{Site}` — Site names (joined twice: from + to)
- `{User}` — User names (joined twice: created by + approved by)

## Index Recommendations

**Status**: Recommended (Pending DBA review)

1. **IX_Transfer_IsApproved_FromSiteId** (IsApproved, FromSiteId)
   - Impact: High
   - Reason: WHERE filtering on approval status + site
   - Status: Recommended

2. **IX_StockMovement_MovementTypeId_DeliverySiteId** (MovementTypeId, DeliverySiteId)
   - Impact: High
   - Reason: WHERE filtering on movement type + receiving site
   - Status: Recommended

## Files

- `query.sql` — Production query (OutSystems Advanced SQL)
- `output-structure.json` — OutSystems Output Structure definition
- `tests/test-ssms.sql` — SSMS test version with DECLARE + STRING_SPLIT
