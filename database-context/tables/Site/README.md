# Site Table

**Schema**: `{Site}`
**Type**: Master Data (Reference Table)
**Purpose**: Store and restaurant location information

## Overview

The Site table contains master data for all store/restaurant locations in the system. Each site represents a physical location with business details, activation status, and timezone information. This table is used to filter data by location and display site names in reports.

## Columns

| Column Name | Data Type | Nullable | Description |
|------------|-----------|----------|-------------|
| `Id` | BIGINT | NOT NULL | OutSystems internal primary key (auto-generated) |
| `Name` | VARCHAR | NULL | Short site name/code |
| `DisplayName` | VARCHAR | NULL | Full display name for UI |
| `LocationId` | BIGINT | NULL | Reference to location hierarchy |
| `BusinessId` | BIGINT | NULL | Reference to business entity |
| `StartDate` | DATETIME | NULL | Site opening/activation date |
| `EndDate` | DATETIME | NULL | Site closing/deactivation date |
| `Id_Branch` | BIGINT | NULL | Branch identifier |
| `Id_Site` | BIGINT | NULL | **SWC Site ID** (used for joins to SalesFact) |
| `isActive` | BOOLEAN | NULL | Active status flag (1 = active, 0 = inactive) |
| `LastUpdated` | DATETIME | NULL | Last modification timestamp |
| `BrowserTimezoneId` | VARCHAR | NULL | Browser timezone identifier |
| `BusinessOwner_Id` | BIGINT | NULL | Business owner reference |
| `OnTarget_DBName` | VARCHAR | NULL | OnTarget database name |
| `DatabaseName` | VARCHAR | NULL | Database name |
| `ConceptId` | BIGINT | NULL | Concept/brand identifier |
| `StateCode` | VARCHAR | NULL | State/province code |
| `CountryCode` | VARCHAR | NULL | Country code |
| `NP6OperatorListRequested` | BOOLEAN | NULL | NP6 operator list request flag |
| `NP6OpListLastDownloadedAt` | DATETIME | NULL | Last NP6 operator download timestamp |

## Key Columns

### Primary Key
- `Id` - OutSystems internal identifier - **USE THIS** for joins to SalesFact and internal tables

### Business Key
- `Id` - OutSystems internal primary key - **USE THIS** for joins to SalesFact
- `Id_Site` - **External SWC Site ID** - Used for external Xero tables only, NOT for SalesFact

### Display Columns
- `Name` - Short site name/code
- `DisplayName` - Full display name (preferred for reports)

### Filter Columns
- `isActive` - Boolean flag for active/inactive sites
- `StartDate` / `EndDate` - Date range for site operation

## Relationships

### Joins to Fact Tables
```sql
-- Join Site to SalesFact using Id (OutSystems internal ID)
FROM {SalesFact} sf
INNER JOIN {Site} s ON sf.SiteId = s.Id
```

**CRITICAL - Id vs Id_Site**:
- **Use `Site.Id`** when joining to SalesFact and internal tables
- `Site.Id` corresponds to `SalesFact.SiteId`
- **Use `Site.Id_Site`** ONLY for external Xero tables
- `Id_Site` is the external system identifier, NOT used for internal joins

### Multi-Tenant Support
- **`Is Multi-tenant = Yes`** on the Site entity — OutSystems auto-filters by current tenant
- `{Site}` in Advanced SQL blocks will **only return current tenant's sites**
- SQL Sandbox does NOT apply tenant filtering (misleading for testing)

### Cross-Tenant Access
When you need all sites across tenants (e.g., Transfer Favourites):
- **Module**: `Access_MCW_V2` — has Site with **Show Tenant Identifier** enabled
- **Server Action**: `GetAllSitesByCountryCode` (located in `Access_MCW_V2`)
  - Input: `CountryCode` (Text), `SiteId` (LongInteger — to exclude)
  - Output: List of `{Id, Name, CountryCode}`
- **Do NOT use `{Site}` in Advanced SQL** for cross-tenant queries — it will be tenant-filtered
- **Do NOT use physical table names** (e.g., `[OSDEV1].dbo.[OSUSR_H1R_SITE_T18]`) — they don't work in Advanced SQL blocks

## Common Patterns

### Filter Active Sites Only
```sql
SELECT s.Id_Site, s.DisplayName
FROM {Site} s
WHERE s.isActive = 1
```

### Optional Site Filter (All Sites or Specific Site)
```sql
-- @SiteId can be NULL for all sites, or specific BIGINT for single site
WHERE (@SiteId IS NULL OR s.Id = @SiteId)
  AND (@ActiveOnly = 0 OR s.isActive = 1)
```

### Get Site Name in Reports
```sql
SELECT
    sf.CalendarDate,
    s.DisplayName AS SiteName,
    SUM(sf.NetAmount) AS Sales
FROM {SalesFact} sf
INNER JOIN {Site} s ON sf.SiteId = s.Id
WHERE s.isActive = 1
GROUP BY sf.CalendarDate, s.DisplayName
```

## Data Notes

- **OutSystems Internal ID**: `Id` is the primary key - **USE THIS** for joins to SalesFact and internal tables
- **External SWC Site ID**: `Id_Site` is for external Xero tables only - NOT used for SalesFact joins
- **Active Status**: Use `isActive = 1` to filter for currently active sites
- **Display Name**: Prefer `DisplayName` over `Name` for user-facing reports
- **Tenant Filtering**: `Is Multi-tenant = Yes` — `{Site}` auto-filters by tenant in Advanced SQL. For cross-tenant access, use `Access_MCW_V2` module's Server Action

## Usage in Queries

### Always Use Id for SalesFact Joins
```sql
-- ✅ CORRECT
FROM {SalesFact} sf
INNER JOIN {Site} s ON sf.SiteId = s.Id

-- ❌ WRONG
FROM {SalesFact} sf
INNER JOIN {Site} s ON sf.SiteId = s.Id_Site  -- This is for Xero tables only!
```

### Optional Multi-Site Support
When allowing users to query all sites or a specific site:
```sql
DECLARE @SiteId BIGINT = NULL;  -- NULL = all sites, or specific ID
DECLARE @ActiveOnly BIT = 1;    -- 1 = active only, 0 = all sites

WHERE (@SiteId IS NULL OR s.Id = @SiteId)
  AND (@ActiveOnly = 0 OR s.isActive = 1)
```

## Performance Considerations

- **Indexing**: Ensure index on `Id` (primary key) for optimal join performance
- **Active Filter**: `isActive` column should be indexed if frequently filtered
- **Tenant Isolation**: OutSystems auto-filters by tenant. Cross-tenant access via `Access_MCW_V2` only

## Related Tables

- **SalesFact**: Joins via `SalesFact.SiteId = Site.Id`
- **External Xero Tables**: Joins via `Site.Id_Site` (not used for SalesFact)
- **Location Hierarchy**: May join via `LocationId` (if needed)
- **Business Entity**: May join via `BusinessId` (if needed)

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-18 | Initial documentation created | Claude |
| 2026-04-07 | Added multi-tenant details, cross-tenant access via Access_MCW_V2 | Claude |
