# Session: Stock Transfers List - 2026-03-31

## Original Story/Requirements
**PRD 1.3 - Inter-Store Stock Transfers**, Story 1.3.1: View Transfer List

User wants to see a list of all stock transfers involving their accessible sites. Supports Pending and Completed views with direction indicators, context-aware status badges, store filter, and date range filter.

## Status
- [ ] Complete / [X] In Progress / [ ] In Testing
- Reopened 2026-04-13 to remove SiteFavorties dependency + add filter sites utility query
- Git commit (original): `6a250d9`

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
  - Parameters: @SiteIds (inline), @ViewType, @FilterSiteId, @StartDate, @EndDate, @SelectedSiteId, @CountryCode

- `queries/stock/stock-transfers-filter-sites/` - Status: **NEW** (2026-04-13)
  - Purpose: Returns distinct sites from visible transfers for filter dropdown
  - Tables used: Transfer, StockMovement, Site
  - Output: SiteId, SiteName (NULL for cross-tenant)
  - Parameters: @SiteIds (inline), @ViewType, @SelectedSiteId, @StartDate, @EndDate

## Key Decisions
- **Single query for both views**: One query with @ViewType parameter ('P'/'A') rather than two separate queries. OutSystems shows/hides columns based on view.
- **Direction determined in OutSystems**: SQL returns FromSiteId/ToSiteId; OutSystems compares against viewing user's current site to show In/Out badge.
- **Status badge determined in OutSystems**: SQL returns IsApproved + site IDs; OutSystems builds the context-aware badge text.
- **Pending amounts from line items**: For pending transfers, StockMovement amounts are null (set on approval), so query calculates from StockMovementLine with country-specific GST rate.
- **MovementTypeId = 2**: Transfer type confirmed from OutSystems entity data screenshot.
- **@SiteIds as Expand Inline = YES**: User confirmed sites will be passed as comma-separated list.
- **@FilterSiteId = 0 means all**: Using 0 as "no filter" value since site IDs are positive integers.
- **Country-based GST**: @CountryCode param → AU=10%, NZ/Fj=15%.

## PRD Coverage (Story 1.3.1)
- [X] Transfer list shows only transfers where user's sites appear as sender or receiver
- [X] Pending/Completed toggle via @ViewType parameter
- [X] Pending columns: Direction (via FromSiteId/ToSiteId), Invoice ID, Date, From, To, Lines, ExGST, Total, Status
- [X] Completed columns: Direction, Invoice ID, Date, From, To, Lines, ExGST, GST, Total, ApprovedBy (out), ApprovedBy (in)
- [X] Store filter via @FilterSiteId
- [X] Date range filter via @StartDate/@EndDate (Completed view only)
- [X] Filter dropdown populated from actual transfer data (new utility query)
- [ ] Pending count badge — separate query or OutSystems aggregate (TBD)
- [ ] Export button — OutSystems UI concern, not SQL

## Cross-Tenant Site Names (2026-04-13 — Updated Approach)

### Previous Approach (REMOVED)
Used `{SiteFavorties}` table with `FavouriteNames` CTE + COALESCE fallback. Removed because SiteFavorties is not the right table for this purpose.

### Current Approach
- SQL uses `LEFT JOIN {Site}` — returns NULL for cross-tenant site names
- OutSystems resolves NULL names **after** SQL returns, via `access_mcw` Server Action
- Filter dropdown populated from a **separate utility query** (`stock-transfers-filter-sites`) that returns distinct SiteIds from the transfers data itself — no longer depends on SiteFavorties

### Behaviour
| Scenario | Name resolves in SQL? | Name resolves in OutSystems? |
|----------|----------------------|------------------------------|
| Same-tenant site | Yes (via `{Site}`) | N/A |
| Cross-tenant site | No (NULL) | Yes (via access_mcw) |

## Next Steps
1. Test list query in OutSystems with access_mcw name resolution
2. Test filter-sites utility query
3. Wire up filter dropdown to use utility query results
4. Handle cross-tenant name resolution in OutSystems Data Action

## Notes for Next Session
- GST rate now country-aware: AU=10%, NZ=15%, Fj=15% (via @CountryCode param)
- The "Approved by (out)" column on Completed view = CreatedByName (sender who created = auto-approved outgoing)
- The "Approved by (in)" column = ApprovedByName (receiver who approved)
- No ORDER BY in production query per CLAUDE.md rules — OutSystems handles sorting
- `{User}` is still tenant-filtered — cross-tenant user names return NULL (denormalization attempt previously broke, reverted)

## Quick Resume
To continue:
1. Read table docs: `database-context/tables/Transfer/README.md`
2. Check list query: `queries/stock/stock-transfers-list/query.sql`
3. Check filter query: `queries/stock/stock-transfers-filter-sites/query.sql`
4. Continue from: OutSystems integration + testing
