# Stock Transfers Filter Sites

## Purpose
Returns all distinct sites (From + To) appearing in the user's visible transfers. Used to populate the store filter dropdown on the Transfers List screen.

## How It Works
1. Fetches all transfers matching the current view filters (same logic as the list query, minus `@FilterSiteId`)
2. Unpivots `FromSiteId` + `ToSiteId` into a single distinct list via `UNION`
3. LEFT JOINs `{Site}` for names — cross-tenant sites return `SiteName = NULL`
4. OutSystems resolves NULL names via `access_mcw` Server Action

## Parameters

| Parameter | Type | Expand Inline | Description |
|-----------|------|--------------|-------------|
| @SiteIds | VARCHAR | YES | Comma-separated Site IDs the user has access to |
| @ViewType | VARCHAR | NO | 'P' = Pending, 'A' = Approved/Completed |
| @SelectedSiteId | BIGINT | NO | Currently selected sidebar site (0 = all) |
| @StartDate | DATE | NO | Optional start date filter (Completed view only) |
| @EndDate | DATE | NO | Optional end date filter (Completed view only) |

## Output Structure

| Column | Type | Description |
|--------|------|-------------|
| SiteId | LongInteger | Site ID |
| SiteName | Text | Site name (NULL for cross-tenant sites) |

## Usage in OutSystems
1. Call this query with the same `@SiteIds`, `@ViewType`, `@SelectedSiteId`, `@StartDate`, `@EndDate` as the list query
2. For any row where `SiteName` is NULL, resolve via `access_mcw` Server Action
3. Populate the filter dropdown with the results
4. When user selects a site from the dropdown, pass its `SiteId` as `@FilterSiteId` to the list query

## Note
This query intentionally does NOT include `@FilterSiteId` — the dropdown shows all available sites for the current view, not a filtered subset.
