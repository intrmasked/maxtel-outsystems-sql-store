# SiteFavourite Table

**Schema**: `{SiteFavourite}`
**Type**: Configuration / User Preference
**Purpose**: Stores a site's favourite sites for use in dropdowns and filters across features (Transfers, etc.)
**Module**: `Stock_CS`

## Overview

Universal favourite sites table. Each site can mark other sites as favourites, including sites from other tenants. Used to populate dropdown lists and filters anywhere a site needs to select from a curated list of other sites rather than the full site list.

## Columns

| Column Name | Data Type | Mandatory | Default | Description |
|-------------|-----------|-----------|---------|-------------|
| `Id` | Long Integer (PK) | Yes | Auto | OutSystems auto-generated primary key |
| `SiteId` | Site Identifier | Yes | — | The site that owns this favourite (FK → Site.Id) |
| `FavouriteSiteId` | Long Integer | Yes | — | The favourited site's Id. **Long Integer, NOT Site Identifier** — avoids tenant-filtered FK constraint for cross-tenant support |
| `FavouriteSiteName` | Text (100) | No | — | Denormalized site name, stored at insert time. Avoids cross-tenant JOIN to `{Site}` when displaying |
| `CountryCode` | Text (10) | No | — | Country code for regional filtering |
| `CreatedBy` | User Identifier | No | — | User who added the favourite |
| `CreatedDate` | Date Time | Yes | `CurrDateTime()` | When the favourite was created |

## Key Design Decisions

### `FavouriteSiteId` is Long Integer, NOT Site Identifier
- If declared as `Site Identifier` (FK), OutSystems enforces a tenant-filtered relationship
- Cross-tenant site IDs would fail validation or be invisible
- **Using plain Long Integer bypasses the FK constraint and tenant filtering**

### `FavouriteSiteName` is Denormalized
- Displaying favourites normally requires JOINing to `{Site}` for the name
- `{Site}` is tenant-filtered — cross-tenant favourite names would come back empty
- **Storing the name at insert time avoids the cross-tenant JOIN problem**
- Trade-off: If a site renames, the cached name goes stale. Acceptable — site renames are extremely rare.

### Multi-Tenant Setting
- `Is Multi-tenant` = **Yes** — favourites belong to a site, and sites are tenant-scoped
- Each tenant only sees their own favourites

## Key Columns

### Primary Key
- `Id` — OutSystems auto-generated identifier

### Foreign Keys
- `SiteId` → `{Site}.Id` (tenant-safe — owning site is always in the current tenant)
- `FavouriteSiteId` → No FK constraint (Long Integer — cross-tenant by design)

### Filter Columns
- `SiteId` — Primary filter: get favourites for a specific site
- `CountryCode` — Secondary filter: regional grouping

## Common Patterns

### Get Favourites for a Site (Dropdown)
```sql
SELECT
    sf.FavouriteSiteId,
    sf.FavouriteSiteName
FROM {SiteFavourite} sf
WHERE sf.SiteId = @SiteId
```
No JOIN to `{Site}` needed — name is denormalized.

### Check if a Site Has Favourites Set Up
```sql
SELECT COUNT(*)
FROM {SiteFavourite} sf
WHERE sf.SiteId = @SiteId
```

### Add a Favourite (OutSystems Entity Action)
Use `CreateSiteFavourite` entity action — no custom SQL needed.
Populate `FavouriteSiteName` from the `GetAllSitesByCountryCode` Server Action result at insert time.

### Remove a Favourite (OutSystems Entity Action)
Use `DeleteSiteFavourite` entity action — no custom SQL needed.

## Related Tables

- **Site**: `SiteId` → `Site.Id` (tenant-safe FK)
- **Site (cross-tenant)**: `FavouriteSiteId` maps to `Site.Id` but without FK — use `Access_MCW_V2` Server Action to resolve names

## Access Control

- **Read**: Any authenticated user (for dropdown population)
- **Write (Add/Delete)**: `StockInvoice_Admin` or `MaxtelSupport` roles only
- Enforced at OutSystems app layer, not in SQL

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-04-07 | Initial documentation created | Claude |
