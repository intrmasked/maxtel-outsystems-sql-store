# Session: Grouped Reports Endpoint — 2026-04-24

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_workitems/edit/3786
**PRD:** See prd.md in this folder
**Mock:** _(not provided)_

## Original Story/Requirements

> The SupportedReport entity will be updated, a ReportModules join table created, and a grouped reports endpoint built.
> - Remove Module field and add Description (nullable string) to SupportedReport
> - Create ReportModules (Id PK, SupportedReportId FK, MaxtelAppId FK) with composite unique on (SupportedReportId, MaxtelAppId); seed from existing module groupings
> - New endpoint returns reports for the current MaxtelAppId grouped by module, each with Description

## Status
- [X] Complete
- Module field removal deferred until full UI migration

## What Was Built

### OutSystems (Service Studio)
1. **SupportedReport** — Added `Description` field (nullable string). Module field kept for backward compat.
2. **ReportModules** — New entity in Report_CS (Id, SupportedReportId FK, MaxtelAppId). Needs composite unique index.
3. **ReportFavourites** — New entity in Report_CS (Id, SupportedReportId FK, BusinessUserId). For feature 2.2.
4. **GetReportsForModule** — Server Action (Private) + Service Action (Public) in Report_CS.

### Server Action: GetReportsForModule

**Structure: ReportForModule**

| Attribute | Type | Description |
|---|---|---|
| SupportedReportId | Long Integer | Report ID |
| ReportName | Text | StructureName |
| Description | Text | Info button text |
| SmartReportTypeUniqueName | Text | For routing |
| IsFavourite | Boolean | Star filled or not |

**Flow:**
- Input: MaxtelAppId, BusinessUserId
- Aggregate: ReportModules → Only With SupportedReport → With or Without ReportFavourites
- Filters: MaxtelAppId match + Is_Active = True
- For Each: map to ReportForModule structure, IsFavourite = ReportFavourites.Id <> NullIdentifier()
- Output: ReportForModule List

### SQL Store (this repo)
- Table docs: SupportedReport, MaxtelApp, ReportModules, ReportFavourites, BusinessUser
- Utility query: `queries/utilities/find-business-user/ and queries/report-control/grouped-reports/tests/` — look up BusinessUserId by name
- Test queries: module mapping investigation, seed reference
- No production SQL needed — endpoint uses Aggregate

## Tables Documentation
- `SupportedReport` — **DONE**
- `ReportModules` — **DONE** (created in OutSystems)
- `ReportFavourites` — **DONE** (created in OutSystems)
- `MaxtelApp` — **DONE**
- `BusinessUser` — **DONE**

## Key Decisions
- **Don't delete Module field yet** — keep until all UI code migrated to ReportModules
- **Seed via UI, not SQL** — Report Settings frontend handles module assignments with new groupings
- **No Advanced SQL needed** — Aggregate handles the endpoint (simple 3-table join)
- **Clean output via Structure** — Server Action maps to ReportForModule structure, UI gets flat list
- **Favourites per user** — BusinessUserId only, no tenant/site scoping needed

## Known User IDs
- Abdul Haseeb: BusinessUserId = 317646, HomeSiteId = 3187

## Deferred
- Remove `Module` field from SupportedReport (after full migration)
- Composite unique index on ReportModules (SupportedReportId, MaxtelAppId)
- "Admin Review" module mapping — 3 reports have no MaxtelApp match
