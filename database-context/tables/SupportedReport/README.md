# Table: SupportedReport

**OutSystems Entity**: SupportedReport
**Module**: Report_CS
**Purpose**: Master list of all reports available in Maxtel Manager. Each row defines a report with its display configuration (which parameter controls to show), smart report identifier, and module assignment.
**Last Updated**: 2026-04-24

---

## Overview

The SupportedReport table is the central registry of all reports in the system. Each report has a unique `SmartReportTypeUniqueName` used for routing, a `Module` field for grouping (being replaced by ReportModules join table), and a large set of boolean `Show*` flags that control which parameter controls appear on the report's configuration form.

**Changes applied (Story #3786):**
- `Module` field removed (replaced by ReportModules many-to-many)
- `Description` field removed — not used in the UI

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | TEXT | PK, NOT NULL | **Report display name** — NOT an auto-number. The Id IS the human-readable name (e.g. "Adjusted Preferred Work Times", "Cash Sheet"). Defined as static Records in OutSystems. |
| `Is_Active` | BIT | NOT NULL | Whether the report is active/visible |
| `StructureName` | VARCHAR | | Secondary name / OutSystems screen structure name. Often empty — NOT the display name. |
| `Module` | VARCHAR | | Module grouping — **REMOVED** (replaced by ReportModules join table) |
| `SmartReportTypeUniqueName` | VARCHAR | UNIQUE | URL-safe identifier for routing (e.g. "cash_sheet", "daily_labour_activity") |
| `ShowSite` | BIT | | Show site selector parameter |
| `ShowWeekSelect` | BIT | | Show week selector parameter |
| `AllowAllSites` | BIT | | Allow "All Sites" option in site selector |
| `ShowDateSelect` | BIT | | Show date picker parameter |
| `ShowBusinessUserSelect` | BIT | | Show business user selector parameter |
| `ShowStartAndEndDate` | BIT | | Show date range (start/end) parameter |
| `ShowCompany` | BIT | | Show company selector parameter |
| `ShowCrewVsAllSwitch` | BIT | | Show crew vs all toggle |
| `ShowPublishedVsLiveSwitch` | BIT | | Show published vs live toggle |
| `ShowEmployeeStatusSwitch` | BIT | | Show employee status toggle |
| `ShowJSONOutput` | BIT | | Show JSON output option |
| `ShowOnlyMissed` | BIT | | Show "only missed" filter |
| `ShowSceduled` | BIT | | Show scheduled filter (note: typo in original) |
| `UseOriginalPublishedHours` | BIT | | Use original published hours flag |
| `ShowEmployeeListingType` | BIT | | Show employee listing type selector |
| `ShowSortOrder` | BIT | | Show sort order selector |
| `ShowLayout` | BIT | | Show layout selector |
| `ShowSalaryType` | BIT | | Show salary type selector |
| `ShowMonthToDateTotal` | BIT | | Show month-to-date total option |
| `ShowCalculateStockVariation` | BIT | | Show stock variation calculation option |
| `ShowWeeklyTotals` | BIT | | Show weekly totals option |
| `ShowMenuFilter` | BIT | | Show menu filter parameter |
| `ShowGroupBy` | BIT | | Show group-by selector |
| `ShowOnTargetLegacyReport` | BIT | | Show on-target legacy report option |
| `ShowRegisterType` | BIT | | Show register type selector |
| `ShowDayPartSales` | BIT | | Show day part sales option |
| `ShowSubscription` | BIT | | Show subscription option |

---

## Key Constraints

### Primary Key
- `Id` - Auto-generated identifier

### Unique Constraints
- `SmartReportTypeUniqueName` - Each report has a unique routing key

---

## Relationships

### Tables That Reference This Table
- **ReportModules** (NEW) - Maps reports to MaxtelApp modules
  - Join: `ReportModules.SupportedReportId = SupportedReport.Id`
- **ReportFavourites** (NEW) - User favourites
  - Join: `ReportFavourites.SupportedReportId = SupportedReport.Id`

---

## Known Module Values

From existing data:
- `Scheduling`
- `Cash`
- `Admin Review`
- `Employee Centre`

---

## Common Query Patterns

### Get all active reports
```sql
SELECT Id, StructureName, Module, SmartReportTypeUniqueName
FROM {SupportedReport}
WHERE Is_Active = 1
```

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-04-24 | Claude | Initial documentation from Service Studio screenshot |
| 2026-05-12 | Claude | Removed Description field, marked Module as removed |
