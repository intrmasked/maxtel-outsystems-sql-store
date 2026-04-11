# Session: Stock Transfers List - 2026-03-31

## Original Story/Requirements
**PRD 1.3 - Inter-Store Stock Transfers**, Story 1.3.1: View Transfer List

User wants to see a list of all stock transfers involving their accessible sites. Supports Pending and Completed views with direction indicators, context-aware status badges, store filter, and date range filter.

## Status
- [ ] Complete / [X] In Progress / [ ] In Testing
- Reopened 2026-04-12 to integrate cross-tenant favourites support
- Query updated: LEFT JOIN + FavouriteNames CTE for cross-tenant name fallback
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

## Cross-Tenant Favourites Integration (2026-04-12)

### Problem
Favourites are cross-tenant — a site can favourite sites in other tenants. The original query used `INNER JOIN {Site}` which drops rows for any cross-tenant FromSiteId/ToSiteId (since `{Site}` is tenant-filtered).

### Solution: Option 2 — Denormalized name fallback
Use denormalized `FavouriteSiteName` from `{SiteFavorties}` as a fallback when `{Site}` doesn't resolve.

### Changes made to `query.sql`:
1. **Added `FavouriteNames` CTE** — dedupes `{SiteFavorties}` to one row per `FavouriteSiteId`:
   ```sql
   FavouriteNames AS (
       SELECT FavouriteSiteId, MAX(FavouriteSiteName) AS FavouriteSiteName
       FROM {SiteFavorties}
       GROUP BY FavouriteSiteId
   )
   ```
2. **Changed `{Site}` joins to LEFT JOIN** — cross-tenant rows no longer dropped
3. **Added `FavouriteNames` LEFT JOINs** for both From/To sides
4. **Output uses COALESCE**:
   ```sql
   COALESCE(fromSite.Name, sfFrom.FavouriteSiteName) AS FromSiteName,
   COALESCE(toSite.Name, sfTo.FavouriteSiteName) AS ToSiteName
   ```

### Data Action Changes (GetTransfersData)
- Now combines tenant sites + favourites into `@SiteIds` list
- Flow: `GetSiteById → SitesInLine → GetSiteFavorites → FavoritesInline → TotalSitesInlineText → TransfersListSQL`
- `TotalSitesInlineText = SitesInLine.Output + "," + FavoritesInline.Output`
- **Open issue**: Inline function outputs `N'3187'` format (text literals) instead of raw integers — need numeric-list helper or manual build

### Behaviour Matrix
| Scenario | Shows up? |
|----------|-----------|
| Transfer between two tenant sites | ✅ (via `{Site}`) |
| Transfer involving favourited cross-tenant site | ✅ (via `FavouriteNames` fallback) |
| Transfer involving non-favourited cross-tenant site | ❌ (not in `@SiteIds`) |

## Next Steps
1. ~~Test query in sandbox with real data~~ ✅ Done — sandbox doesn't apply tenant filtering so results misleading
2. Fix `@SiteIds` format — currently returning `N'3187'` from inline helper, needs to be raw integers
3. Test cross-tenant favourites in actual Advanced SQL block (not sandbox)
4. Verify `COALESCE` fallback resolves cross-tenant names correctly
5. Handle "All Sites" case — `SelectedSiteId = 0` should pull all tenant favourites

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
