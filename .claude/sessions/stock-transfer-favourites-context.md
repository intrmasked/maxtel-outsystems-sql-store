# Session: Stock Transfer Favourite Sites - 2026-04-07

## Original Story/Requirements
**PRD 1.3 - Inter-Store Stock Transfers**, Feature: Transfer Site Favourites

A Site needs to be able to select favourites for use in the Transfer screens. Favourites will display in:
- **TransferList screen** — filter dropdown
- **Create/Edit screen** — site "To Site" dropdown

Requirements:
- New table `SiteFavourite` to store favourites
- Default setup action: set defaults to other active sites in same tenant. If receiving NullSiteId → run for all active sites (one-time on publish to production)
- Settings screen section for managing favourites (add/delete)
- "Edit favourites" link below dropdown lists in transfer screens
- Editable only by `StockInvoice_Admin` or `MaxtelSupport` roles (app-layer enforcement)
- Spelling: "Favourites" (NZ/AU convention) for all UI labels
- **Cross-tenant support**: Users must be able to favourite sites from OTHER tenants

## Status
- [ ] Complete / [X] In Progress / [ ] In Testing
- Current step: Cross-tenant problem solved — moving to Phase 2 queries

## The Cross-Tenant Problem — RESOLVED (Server Action Approach)

### Investigation Journey (2026-04-07)
1. **SQL Sandbox test**: `{Site}` returned 181 NZ sites — appeared to work cross-tenant
2. **Advanced SQL block test**: `{Site}` was tenant-filtered — only returned current tenant's sites
3. **Root cause**: SQL sandbox does NOT apply OutSystems tenant filtering, so sandbox results are misleading for tenant-scoped entities
4. **Physical table attempt**: `[OSDEV1].dbo.[OSUSR_H1R_SITE_T18]` — physical table names don't work in Advanced SQL blocks either
5. **"Show Tenant Identifier" test**: Enabling this on Site entity makes cross-tenant queries work, but Site is used everywhere — too risky to change

### Approaches Considered & Rejected
| Approach | Why Rejected |
|----------|-------------|
| `{Site}` directly | Tenant-filtered in Advanced SQL blocks |
| Physical table name | Doesn't work in Advanced SQL blocks |
| Database View | Would require DB-level changes outside OutSystems |
| New entity mapping same table | OutSystems creates a new physical table per entity |
| Duplicate/sync table | Wasteful — two copies of the same data |
| Flip "Show Tenant Identifier" on Site | Too risky — Site used in many places, would break existing queries |
| New utility module | Overkill for just getting a site list |
| Pass sites from app layer (Expand Inline) | Doesn't solve the root problem of getting the list in the first place |

### Final Solution
**Server Action in an existing module** that already has Site with "Show Tenant Identifier" enabled.

- Found an existing module that references Site with tenant identifier exposed
- Create a **Server Action** in that module: `GetAllSitesByCountryCode`
  - Input: `CountryCode` (Text), `SiteId` (LongInteger — to exclude)
  - Output: List of `{Id, Name, CountryCode}`
  - Uses an Aggregate on their Site reference (already cross-tenant)
- Stock UI module calls this Server Action
- **No SQL query needed** for cross-tenant site retrieval

> **Key Lesson**: `{Site}` entity has `Is Multi-tenant = Yes`. SQL sandbox doesn't apply tenant filtering, so always test tenant-scoped queries in actual Advanced SQL blocks.

### Security Model
- **Never expose more than necessary** — filter by `CountryCode` to restrict to same region
- **Only return safe columns**: `Id`, `Name`, `CountryCode` — no sensitive data
- **Role enforcement** in OutSystems app layer: only `StockInvoice_Admin` / `MaxtelSupport` can edit favourites
- Favourites are **per-site** (my site's favourites, no one else sees them)

### Region Definition
- **CountryCode** on the Site table defines a region
- Filter: `CountryCode = @CountryCode AND isActive = 1`

## Tables

### Existing Tables Used
- `{Site}` — Site table (`Is Multi-tenant = Yes`, tenant-filtered in Advanced SQL)
- Site via existing module's Server Action — cross-tenant access (Show Tenant Identifier enabled)

### New Table: `SiteFavourite`
| Column | Data Type | Mandatory | Description |
|--------|-----------|-----------|-------------|
| `Id` | Long Integer (PK) | Yes | OutSystems auto-generated PK |
| `SiteId` | Site Identifier | Yes | The site that owns this favourite (FK → Site.Id) |
| `FavouriteSiteId` | Long Integer | Yes | The favourited site — **NOT Site Identifier** (avoids tenant-filtered FK for cross-tenant support) |
| `FavouriteSiteName` | Text (100) | No | Denormalized name — stored at insert time to avoid cross-tenant JOIN |
| `CountryCode` | Text (10) | No | Country code for filtering |
| `CreatedBy` | User Identifier | No | User who added the favourite |
| `CreatedDate` | Date Time | Yes | Default: `CurrDateTime()` |

**Key**: `FavouriteSiteId` is Long Integer (not Site Identifier) to bypass tenant FK. `FavouriteSiteName` is denormalized to avoid cross-tenant JOIN.
**Module**: `Stock_CS` (universal — not tied to transfers)
**Table docs**: `database-context/tables/SiteFavourite/README.md` ✅ Created

## Backend Action Plan

### Phase 1: Cross-Tenant Foundation — DONE (No SQL needed)
| # | Item | Type | Status |
|---|------|------|--------|
| 1 | `GetAllSitesByCountryCode` | Server Action (existing module) | **To build in OutSystems** |

**Not a SQL query** — handled via OutSystems Aggregate in a module with Show Tenant Identifier enabled.

### Phase 2: Favourites CRUD

| # | Query Name | Category | Purpose | Priority |
|---|-----------|----------|---------|----------|
| 2 | `get-favourite-sites` | `stock` | Get a site's favourite sites for dropdown population. Joins `{SiteFavourite}` with `{Site}` to get display names. Since favourites store the SiteId, and we only need to display names for already-saved favourites, `{Site}` tenant filtering may or may not be an issue here — need to verify. | **P1 — Next** |
| 3 | `setup-default-favourites` | `stock` | INSERT default favourites for a site (or all active sites if NullSiteId). Defaults = other active sites in same tenant (uses `{Site}` which is tenant-safe for same-tenant). Idempotent — skips sites that already have favourites. | **P1** |
| 4 | `add-favourite-site` | `stock` | INSERT a single favourite. Likely handled by OutSystems entity action — TBD. | **P2** |
| 5 | `remove-favourite-site` | `stock` | DELETE a single favourite. Likely handled by OutSystems entity action — TBD. | **P2** |

### Phase 3: UI Integration (Later)
- Settings screen section for favourites management
- "Edit favourites" link in transfer screen dropdowns
- Role-based visibility (`StockInvoice_Admin` / `MaxtelSupport`)
- **All UI work deferred** — backend first per user request

## Key Decisions
- **Server Action for cross-tenant sites**: Use existing module with Show Tenant Identifier on Site, expose Server Action. No SQL needed for this part.
- **CountryCode as region filter**: Simpler than ConceptId, gives the right geographical grouping
- **Favourites are per-site**: Not per-user, not per-tenant — each site has its own favourite list
- **Backend first**: UI deferred to later phase
- **Spelling**: "Favourites" (NZ/AU) in all labels and docs; table/column names use "Favourite" too
- **Add/Remove may not need SQL**: OutSystems entity actions can handle simple CRUD — evaluate when we get to Phase 2

## Folder Structure Plan
```
queries/stock/get-favourite-sites/         ← Phase 2
├── query.sql
├── README.md
├── metadata.json
├── output-structure.json
└── tests/
    └── test-ssms.sql

queries/stock/setup-default-favourites/    ← Phase 2
├── query.sql
├── README.md
├── metadata.json
└── tests/
    └── test-ssms.sql

database-context/tables/SiteFavourite/
└── README.md
```

## Next Steps
1. **Build Server Action** `GetAllSitesByCountryCode` in existing module (OutSystems work, not SQL)
2. **Create table docs** for `SiteFavourite` (once entity is created)
3. **Build `get-favourite-sites` query** (Phase 2) — need to verify if `{Site}` join works for cross-tenant favourite names
4. **Build `setup-default-favourites` query** (Phase 2)
5. Evaluate if add/remove need custom SQL or OutSystems entity actions

## Notes for Next Session
- Physical table name (for reference): `[OSDEV1].dbo.[OSUSR_H1R_SITE_T18]`
- **`{Site}` IS tenant-filtered** in Advanced SQL blocks (sandbox is misleading)
- Cross-tenant site list handled via Server Action, NOT SQL
- `get-favourite-sites` query will need to join favourites to Site for names — may hit the same tenant issue if favourite sites are from other tenants. Consider denormalizing site name into the favourites table.
- Role checks (`StockInvoice_Admin` / `MaxtelSupport`) are app-layer — not in SQL
- The `SiteFavourite` table doesn't exist yet — user will create it in OutSystems

## Quick Resume
To continue:
1. Read this context file
2. Build Server Action in OutSystems (cross-tenant site list)
3. Create `SiteFavourite` entity in OutSystems
4. Then build Phase 2 SQL queries
