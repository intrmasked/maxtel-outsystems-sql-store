# Session: Stock Transfers List - 2026-03-31

## Original Story/Requirements
**PRD 1.3 - Inter-Store Stock Transfers**, Story 1.3.1: View Transfer List

User wants to see a list of all stock transfers involving their accessible sites. Supports Pending and Completed views with direction indicators, context-aware status badges, store filter, and date range filter.

## Status
- [ ] Complete / [ ] In Progress / [X] In Testing
- Current step: Query deployed to OutSystems, runs successfully (empty data — Transfer entity columns just added)
- Incomplete items: Real data testing once Create Transfer screen is built
- Git commit: `6a250d9`

## Tables Documentation Created
- `database-context/tables/StockMovement/` - **NEW** - Parent record for all stock movements
- `database-context/tables/StockMovementLine/` - **NEW** - Line items within a movement
- `database-context/tables/Transfer/` - **NEW** - Extension for transfer-type movements
- `database-context/tables/BO_RawItemPrice/` - **NEW** - Historical item prices
- `database-context/tables/User/` - **NEW** - System user entity
- `database-context/tables/MovementType/` - **NEW** - Movement type enum (Adjustment=1, Transfer=2, Delivery=3)
- `database-context/tables/Site/` - EXISTING - Store/location data

## Queries Created
- `queries/stock/stock-transfers-list/` - Status: in-progress
  - Purpose: Transfer list for Pending/Completed views
  - Tables used: Transfer, StockMovement, StockMovementLine, Site, User
  - Output: StockMovementId, FromSiteId, ToSiteId, site names, dates, line count, amounts, approval info
  - Parameters: @SiteIds (inline), @ViewType, @FilterSiteId, @StartDate, @EndDate

## Key Decisions
- **Single query for both views**: One query with @ViewType parameter ('P'/'C') rather than two separate queries. OutSystems shows/hides columns based on view.
- **Direction determined in OutSystems**: SQL returns FromSiteId/ToSiteId; OutSystems compares against viewing user's current site to show In/Out badge.
- **Status badge determined in OutSystems**: SQL returns IsApproved + site IDs; OutSystems builds the context-aware badge text.
- **Pending amounts from line items**: For pending transfers, StockMovement amounts are null (set on approval), so query calculates from StockMovementLine with 10% GST assumption.
- **MovementTypeId = 2**: Transfer type confirmed from OutSystems entity data screenshot.
- **@SiteIds as Expand Inline = YES**: User confirmed sites will be passed as comma-separated list.
- **@FilterSiteId = 0 means all**: Using 0 as "no filter" value since site IDs are positive integers.

## PRD Coverage (Story 1.3.1)
- [X] Transfer list shows only transfers where user's sites appear as sender or receiver
- [X] Pending/Completed toggle via @ViewType parameter
- [X] Pending columns: Direction (via FromSiteId/ToSiteId), Invoice ID, Date, From, To, Lines, ExGST, Total, Status
- [X] Completed columns: Direction, Invoice ID, Date, From, To, Lines, ExGST, GST, Total, ApprovedBy (out), ApprovedBy (in)
- [X] Store filter via @FilterSiteId
- [X] Date range filter via @StartDate/@EndDate (Completed view only)
- [ ] Pending count badge — separate query or OutSystems aggregate (TBD)
- [ ] Export button — OutSystems UI concern, not SQL

## Next Steps
1. Test query in sandbox with real data
2. Verify column alignment with OutSystems Output Structure
3. Consider if pending count badge needs a separate lightweight query
4. Move to Story 1.3.2 (Transfer Detail) when ready

## Notes for Next Session
- GST rate hardcoded at 10% for pending transfer amount calculation — confirm with user
- The "Approved by (out)" column on Completed view = CreatedByName (sender who created = auto-approved outgoing)
- The "Approved by (in)" column = ApprovedByName (receiver who approved)
- No ORDER BY in production query per CLAUDE.md rules — OutSystems handles sorting

## Quick Resume
To continue:
1. Read table docs: `database-context/tables/Transfer/README.md`
2. Check query: `queries/stock/stock-transfers-list/query.sql`
3. Continue from: Sandbox testing
