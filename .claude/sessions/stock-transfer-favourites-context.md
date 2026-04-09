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
- Current step: Backend done — moving to UI (Phase 3)

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

## Phase 3: UI Integration — IN PROGRESS

### Settings Screen — Favourites Management
**Pattern**: Searchable dropdown + favourites list
- Search dropdown at top to find and add sites (cross-tenant via `GetAllSitesByCountryCode`)
- Below: list of current favourites with remove button on each row
- Role-restricted: `StockInvoice_Admin` or `MaxtelSupport` only

**Layout**:
```
[Settings Section: Transfer Favourites]
┌─────────────────────────────────────┐
│ Add site: [🔍 Search sites...    ▾] │
├─────────────────────────────────────┤
│ Coastlands                    [✕]  │
│ Mana                          [✕]  │
│ Paraparaumu                   [✕]  │
│ Porirua Plaza                 [✕]  │
└─────────────────────────────────────┘
```

### Transfer Screen Dropdown Integration
- Dropdowns show favourites only (from `{SiteFavorties}`)
- Empty state: "No Sites" with "Edit Favourites" link
- "Edit Favourites" link below dropdown options

### "Populate All" Button
- In settings screen, button calls `SetupDefaultFavourites` with `NullIdentifier()`
- One-time use on first publish to production
- Idempotent — won't overwrite existing favourites

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

## Next Steps
1. **Build settings screen UI** — searchable dropdown + favourites list
2. **Wire "Populate All" button** in settings
3. **Integrate favourites into transfer screen dropdowns**
4. **Handle empty state** — "No Sites" + "Edit Favourites" link
5. **Role checks** — restrict editing to StockInvoice_Admin / MaxtelSupport

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
