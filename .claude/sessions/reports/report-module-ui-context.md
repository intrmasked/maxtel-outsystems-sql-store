# Session: Report Module UI — 2026-04-26

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_workitems/edit/3787
**PRD:** See prd.md in this folder
**Mock:** _(not provided)_

## Original Story/Requirements

> The Reports module will be rebuilt with a module specific navigation in the sidebar and updated
> - Menu bar renders module groups from the API; only modules with assigned reports are shown, each with a report count
> - Two-column card grid for the active module — each card shows a star and an info tooltip displaying Description
> - Report slideover is maintained

## Status
- [X] Complete
- All work is OutSystems UI + Aggregate-based Server/Service Actions (no SQL needed)

## Dependencies
- **Story #3786** (complete) — GetReportsForModule endpoint, ReportModules + ReportFavourites tables

## What Was Built

### Endpoints (Report_CS — Aggregates, no SQL)

**1. GetReportModuleList** — Sidebar module list

Structure: `ReportModuleItem`

| Attribute | Type | Description |
|---|---|---|
| MaxtelAppId | Long Integer | Pass to GetReportsForModule |
| ModuleName | Text | Display name in sidebar |
| ReportCount | Integer | Count badge next to name |

Flow:
- Aggregate: ReportModules → Only With SupportedReport (Is_Active=True) → Only With MaxtelApp
- Group By: MaxtelApp.Id, MaxtelApp.Name
- Count: SupportedReport.Id
- Sort: MaxtelApp.Name ASC
- For Each → map to ReportModuleItem
- Output: ReportModuleItem List
- Wrap in Service Action

**2. GetReportsForModule** — Card grid data (from story #3786)

Structure: `ReportForModule`

| Attribute | Type | Description |
|---|---|---|
| SupportedReportId | Long Integer | Report ID |
| ReportName | Text | StructureName |
| Description | Text | Info tooltip |
| SmartReportTypeUniqueName | Text | For routing |
| IsFavourite | Boolean | Star icon state |

Flow:
- Input: MaxtelAppId, BusinessUserId
- Aggregate: ReportModules → Only With SupportedReport → With or Without ReportFavourites
- Filters: MaxtelAppId match + Is_Active = True
- For Each → map to ReportForModule, IsFavourite = ReportFavourites.Id <> NullIdentifier()
- Output: ReportForModule List
- Wrap in Service Action

### UI Flow (Report_UI)

```
Page Load
├─ Call GetReportModuleList
├─ Render sidebar: ModuleName (ReportCount) for each item
├─ Auto-select first module
│
User clicks module in sidebar
├─ Call GetReportsForModule(MaxtelAppId, BusinessUserId)
├─ Render two-column card grid
│   ├─ Card: ReportName + star icon (IsFavourite) + info tooltip (Description)
│   └─ Click card → open report parameter form / slideover
│
Star icon click
├─ Toggle favourite (entity action INSERT/DELETE on ReportFavourites)
├─ Optimistic UI update
```

## Query Folder Structure

```
queries/report-control/          ← backend/control queries (not actual reports)
├─ grouped-reports/tests/        ← test queries from story #3786
└─ report-module-list/           ← (empty — no SQL needed, uses Aggregate)

queries/reports/                 ← actual report queries (sales, stock, etc.)
```

## Key Decisions
- **Fully dynamic sidebar** — module names and counts from API, not hardcoded
- **Separated report-control from reports** — `queries/report-control/` for UI/backend control, `queries/reports/` for actual report queries
- **No SQL needed** — both endpoints use Aggregates
- **Slideover maintained** — no changes to existing slideover behaviour

## Known User IDs
- Abdul Haseeb: BusinessUserId = 317646, HomeSiteId = 3187
