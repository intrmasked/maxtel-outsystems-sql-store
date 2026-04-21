# Session: Stock Transfer Favourite Sites - 2026-04-07

## Original Story/Requirements
**PRD 1.3 - Inter-Store Stock Transfers**, Feature: Transfer Site Favourites

A Site needs to be able to select favourites for use in the Transfer screens. Favourites will display in:
- **TransferList screen** — filter dropdown
- **Create/Edit screen** — site "To Site" dropdown

Requirements:
- New table `SiteFavorties` to store favourites
- Default setup action: set defaults to other active sites in same tenant. If receiving NullSiteId → run for all active sites (one-time on publish to production)
- Settings screen section for managing favourites (add/delete)
- "Edit favourites" link below dropdown lists in transfer screens
- Editable only by `StockInvoice_Admin` or `MaxtelSupport` roles (app-layer enforcement)
- Spelling: "Favourites" (NZ/AU convention) for all UI labels
- **Cross-tenant support**: Users must be able to favourite sites from OTHER tenants

## Status
- [ ] Complete / [X] In Progress / [ ] In Testing
- Current step: Transfer List integration in progress. Create screen integration pending.

## The Cross-Tenant Problem — RESOLVED (Server Action Approach)

### Investigation Journey (2026-04-07)
1. **SQL Sandbox test**: `{Site}` returned 181 NZ sites — appeared to work cross-tenant
2. **Advanced SQL block test**: `{Site}` was tenant-filtered — only returned current tenant's sites
3. **Root cause**: SQL sandbox does NOT apply OutSystems tenant filtering, so sandbox results are misleading for tenant-scoped entities
4. **Physical table attempt**: `[OSDEV1].dbo.[OSUSR_H1R_SITE_T18]` — physical table names don't work in Advanced SQL blocks either
5. **"Show Tenant Identifier" test**: Enabling this on Site entity makes cross-tenant queries work, but Site is used everywhere — too risky to change

### Final Solution
**Server Action in `Access_MCW_V2`** — already has Site with "Show Tenant Identifier" enabled.
- `GetAllSitesByCountryCode(CountryCode, SiteId)` → returns cross-tenant site list
- Stock UI module consumes this Service Action

> **Key Lesson**: `{Site}` entity has `Is Multi-tenant = Yes`. SQL sandbox doesn't apply tenant filtering, so always test tenant-scoped queries in actual Advanced SQL blocks.

## Tables

### Existing Tables Used
- `{Site}` — Site table (`Is Multi-tenant = Yes`, tenant-filtered in Advanced SQL)
- Site via `Access_MCW_V2` Server Action — cross-tenant access (Show Tenant Identifier enabled)

### Table: `{SiteFavorties}` (entity name has typo, kept as-is)
| Column | Data Type | Mandatory | Description |
|--------|-----------|-----------|-------------|
| `Id` | Long Integer (PK) | Yes | OutSystems auto-generated PK |
| `SiteId` | Site Identifier | Yes | The site that owns this favourite (FK → Site.Id) |
| `SiteName` | Text (100) | No | Denormalized name of the owning site — stored at insert time |
| `FavouriteSiteId` | Long Integer | Yes | The favourited site — **NOT Site Identifier** (avoids tenant-filtered FK) |
| `FavouriteSiteName` | Text (100) | No | Denormalized name — stored at insert time |
| `FavouriteCountryCode` | Text (10) | No | Country code of the favourited site |
| `CreatedBy` | User Identifier | No | User who added the favourite |
| `CreatedDate` | Date Time | Yes | Default: `CurrDateTime()` |

**Module**: `Stock_CS`
**Table docs**: `database-context/tables/SiteFavourite/README.md` ✅

## Backend — COMPLETE ✅

### Phase 1: Cross-Tenant Foundation ✅
| # | Item | Type | Status |
|---|------|------|--------|
| 1 | `GetAllSitesByCountryCode` | Service Action (`Access_MCW_V2`) | ✅ Built & tested |

### Phase 2: Favourites Management ✅
| # | Item | Type | Status |
|---|------|------|--------|
| 2 | `SiteFavorties` entity | Entity (`Stock_CS`) | ✅ Created |
| 3 | `SetupDefaultFavourites` | Server Action (`Stock_CS`) | ✅ Built & tested |
| 4 | Add/Remove favourites | OutSystems entity actions | ✅ `CreateSiteFavorties` / `DeleteSiteFavorties` |

### SetupDefaultFavourites — Server Action
**Input**: `SiteId` (Site Identifier) — specific site or `NullIdentifier()` for all
**Logic**:
1. `GetSites` aggregate: `{Site} WHERE isActive = True AND (SiteId = NullIdentifier() OR Site.Id = SiteId)`
2. For each site:
   - Check `{SiteFavorties}` count for that site — if > 0, skip (idempotent)
   - Get other active sites in same tenant
   - Create `SiteFavorties` record for each (with denormalized name + country code)
3. Return done message
**Tested**: Site 3189 populated successfully

## Phase 3: Settings Panel — COMPLETE ✅

### Settings Screen — Favourites Management
**Pattern**: Dropdown + Add button + Datagrid with remove

**Conditional logic**:
- If `SelectedSiteId <> NullIdentifier()` → site is pre-selected, hide site picker
- If `SelectedSiteId = NullIdentifier()` → show site picker, allow managing any site's favourites

**Layout**:
```
[▾ Select site (owner)  ]  [▾ Select favourite site ]  [+ Add]
 ↑ hidden if SelectedSiteId    ↑ cross-tenant list
   is already set               (GetAllSitesByCountryCode)

| Site (owner)     | Favourite Site   | Action  |
|------------------|------------------|---------|
| Coastlands       | Mana             | Remove  |
| Coastlands       | Paraparaumu      | Remove  |
| Coastlands       | Porirua Plaza    | Remove  |

[Populate Defaults]  ← bottom, show when empty or MaxtelSupport
```

**Datagrid columns**:
- `SiteName` — owning site (denormalized from `{SiteFavorties}.SiteName`)
- `FavouriteSiteName` — the favourited site
- Remove button — calls `DeleteSiteFavorties`

**Data sources**:
- Datagrid: Aggregate on `{SiteFavorties}`, filtered by SiteId if SelectedSiteId set
- Favourite dropdown: `GetAllSitesByCountryCode` (cross-tenant)
- Site dropdown: standard `{Site}` aggregate (current tenant only)

### Transfer Screen Dropdown Integration
- Dropdowns show favourites only (from `{SiteFavorties}` aggregate)
- Empty state: "No Sites" with "Edit Favourites" link
- "Edit Favourites" link below dropdown options

### "Populate All" Button
- In settings screen, button calls `SetupDefaultFavourites` with `NullIdentifier()`
- One-time use on first publish to production
- Idempotent — won't overwrite existing favourites

### Table Change (2026-04-09)
- Added `SiteName` column (Text 100) — denormalized owning site name
- Cleared all existing data (`DELETE FROM {SiteFavorties}`) and re-ran `SetupDefaultFavourites`

## Phase 4: CRUD Server Actions — COMPLETE ✅

### Stock_CS Module — Server Actions (Private)

**1. AddSiteFavourites** (Server Action, Private) ✅
- **Input**: `SiteId` (Site Identifier), `FavouriteSiteId` (Long Integer), `FavouriteSiteName` (Text), `FavouriteCountryCode` (Text)
- **Logic**:
  1. Duplicate check → Aggregate `{SiteFavorties}` WHERE `SiteId = SiteId AND FavouriteSiteId = FavouriteSiteId`
  2. If NOT empty → throw Application Exception "Already a favourite"
  3. Get owner site name → Aggregate `{Site}` WHERE `Id = SiteId`
  4. Create record with all fields + `CreatedBy = GetUserId()`, `CreatedDate = CurrDateTime()`
- **Note**: Server looks up `SiteName` (owner) itself. Client sends `FavouriteSiteName` + `FavouriteCountryCode` from dropdown data.
- **Bug found & fixed**: Initial If condition was backwards (`List.Empty? → True → Exception`). Fixed to `NOT List.Empty? → Exception`.

**2. RemoveSiteFavourite** (Server Action, Private) ✅
- **Input**: `SiteFavortiesId` (SiteFavorties Identifier)
- **Logic**: `DeleteSiteFavorties(SiteFavortiesId)`

### Stock_CS Module — Service Actions (Public wrappers) ✅
- `AddSiteFavourites` (Public) → calls private `AddSiteFavourites`
- `RemoveSiteFavourite` (Public) → calls private `RemoveSiteFavourite`

### UI Module — Client Actions ✅

**AddFavoritesOnClick:**
1. Validate: `Local_FavouriteSiteId <> 0`
2. Determine owner: `If(SelectedSiteId <> NullIdentifier(), SelectedSiteId, Local_SiteId)`
3. Filter AllSites data to get `FavouriteCountryCode`
4. Call `AddSiteFavourites` service action
5. Refresh `GetSiteFavorites` → datagrid updates
6. Reset local variables

**RemoveOnClick** (per datagrid row):
1. Call `RemoveSiteFavourite` with `GetSiteFavorites.List.Current.SiteFavorties.Id`
2. Refresh `GetSiteFavorites` → datagrid updates

**TenantSitesOnChanged** (Owner Site dropdown):
- Stores `SelectedOptionList.Current.Value` → `Local_SiteId`

**AllSitesOnChanged** (Favourite Site dropdown):
- Stores `Value` → `Local_FavouriteSiteId`, `Label` → `Local_FavouriteSiteName`

### Screen Local Variables
| Name | Type | Default |
|------|------|---------|
| `Local_SiteId` | Site Identifier | `NullIdentifier()` |
| `Local_FavouriteSiteId` | Long Integer | `0` |
| `Local_FavouriteSiteName` | Text | `""` |
| `Local_FavouriteCountryCode` | Text | `""` |

### CSS Classes
| Class | Applied To | Purpose |
|-------|-----------|---------|
| `fav-add-row` | Outer Container | `display:flex; gap:12px; align-items:flex-end; margin-bottom:16px` |
| `fav-dropdown` | Each dropdown Container | `flex:1` |

## Key Decisions
- **Server Action for cross-tenant sites**: `Access_MCW_V2` module with Show Tenant Identifier
- **CountryCode as region filter**: Simpler than ConceptId
- **Favourites are per-site**: Not per-user, not per-tenant
- **Service Action pattern**: Private Server Actions in CS, public Service Actions as wrappers
- **Entity name typo**: `SiteFavorties` kept as-is in OutSystems
- **FavouriteSiteId is Long Integer**: Bypasses tenant FK constraint for cross-tenant support
- **FavouriteSiteName denormalized**: Avoids cross-tenant JOIN to `{Site}`
- **SetupDefaultFavourites is idempotent**: Skips sites that already have favourites
- **No ConceptId needed**: SiteId + CountryCode is sufficient

## Phase 5: Transfer Screen Integration — IN PROGRESS

### Transfer List Screen — Data Action Changes
`GetTransfersData` data action flow now combines tenant sites + favourites:
```
GetSiteById → SitesInLine → GetSiteFavorites → FavoritesInline → TotalSitesInlineText → TransfersListSQL
```

**Key assign:**
```
TotalSitesInlineText = SitesInLine.Output + "," + FavoritesInline.Output
```

**SQL query changes** (in `queries/stock/stock-transfers-list/query.sql`):
1. Added `FavouriteNames` CTE — dedupes `{SiteFavorties}` to one row per `FavouriteSiteId`
2. Changed `INNER JOIN {Site}` → `LEFT JOIN {Site}` so cross-tenant rows don't drop
3. Added `LEFT JOIN FavouriteNames` for both sides
4. Output uses `COALESCE(fromSite.Name, sfFrom.FavouriteSiteName)` — tenanted name first, fallback to denormalized favourite name

**Why**: `{Site}` is tenant-filtered, so cross-tenant favourites can't resolve through it. Denormalized `FavouriteSiteName` from `{SiteFavorties}` is the fallback source of truth.

### Open Issues
- **Inline helper output format**: `BuildSafe_InClauseTextList` returns `N'3187'` (Unicode text literals) instead of raw integers like `3187`. Need numeric-list helper or manual ForEach build for `@SiteIds` to work with `IN (@SiteIds)` on a BIGINT column.
- **All Sites case** (`SelectedSiteId = 0`): should pull all tenant favourites, not just one site's — need conditional logic in data action

### Still Pending
1. **Fix `@SiteIds` format** — raw integers, not text literals
2. **All Sites favourites logic** — pull all tenant favourites when SelectedSiteId = 0
3. **Transfer Create screen** — wire "To Site" dropdown to `{SiteFavorties}` aggregate
4. **Handle empty state** — "No Sites" + "Edit Favourites" link in dropdowns
5. **Role checks** — restrict editing to StockInvoice_Admin / MaxtelSupport (settings panel)

## Completed ✅
1. ~~**Build settings screen UI**~~ ✅ Dropdowns + Add button + Datagrid
2. ~~**CRUD server/service actions**~~ ✅ Add + Remove built & working
3. ~~**Settings panel integration in Manager**~~ ✅ Done
4. ~~**Transfer List SQL query — cross-tenant name fallback**~~ ✅ Done (FavouriteNames CTE)

## Notes for Next Session
- Physical table name (ref only): `[OSDEV1].dbo.[OSUSR_H1R_SITE_T18]`
- **`{Site}` IS tenant-filtered** in Advanced SQL blocks
- Cross-tenant list: `GetAllSitesByCountryCode` in `Access_MCW_V2`
- Entity name: `SiteFavorties` (typo, kept as-is)
- Role checks are app-layer only

## Quick Resume
To continue:
1. Read this context file
2. Build settings screen UI (Phase 3)
3. Wire favourites into transfer dropdowns
