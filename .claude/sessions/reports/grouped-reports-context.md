# Session: Grouped Reports Endpoint — 2026-04-24

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_workitems/edit/3786
**PRD:** See prd.md in this folder
**Mock:** _(not provided yet)_

## Original Story/Requirements

> The SupportedReport entity will be updated, a ReportModules join table created, and a grouped reports endpoint built.
> - Remove Module field and add Description (nullable string) to SupportedReport
> - Create ReportModules (Id PK, SupportedReportId FK, MaxtelAppId FK) with composite unique on (SupportedReportId, MaxtelAppId); seed from existing module groupings
> - New endpoint returns reports for the current MaxtelAppId grouped by module, each with Description

## Status
- [ ] In Progress
- Current step: OutSystems entity work (Service Studio), then build aggregate endpoint
- SQL side: No Advanced SQL needed — Aggregate handles this

## Tables Documentation
- `SupportedReport` — **DONE** — documented from Service Studio screenshot
- `ReportModules` — **CREATED** in OutSystems (Report_CS) — needs composite unique index
- `ReportFavourites` — **DOCS DONE** — needs creation in OutSystems
- `MaxtelApp` — **DONE** — documented from Service Studio screenshot (Access_CS)
- `BusinessUser` — not yet documented (Access_CS, referenced by ID only)

## MaxtelApp ID Mapping (from test query)

| Id | Name |
|----|------|
| 1 | (Unassigned) |
| 7 | Scheduling |
| 9 | Employee Files |
| 11 | Smart Reports |
| 12 | Authorise Shifts |
| 13 | Stock Management Module |
| 14 | Employee Centre |
| 15 | Requests |
| 16 | Sales App |
| 17 | Self Service |
| 18 | Reports |
| 19 | Maxtel Back Office |
| 20 | KPI Dashboard |
| 22 | Accounting |
| 23 | Cash |
| 24 | Accounting Reports |

## Old Module → New Module Mapping

The frontend Report Settings UI (already built) uses **new module groupings** that differ from old `SupportedReport.Module` values:

| Old Module (SupportedReport.Module) | New UI Grouping |
|-------------------------------------|-----------------|
| Scheduling | Schedules (5) |
| Cash | Daily Shift (10) |
| Admin Review | Daily Shift (moved) |
| Employee Centre | ??? |
| Stock Count | ??? |
| _(empty)_ | 3 reports unassigned |

**New UI groups**: Daily Shift (10), Schedules (5), Accounting (11), Miscellaneous (3), Employee Turnover (1), Net Promoter Score (1)

## Key Decisions
- **Don't delete Module field yet** — keep it until all UI code migrated to ReportModules
- **Add Description to SupportedReport** — safe, new nullable field
- **Seed via UI, not SQL** — frontend Report Settings page already handles module assignments with new groupings
- **Description populated from frontend** — Report Settings UI has inline description editing
- **No Advanced SQL needed** — Aggregate handles the grouped-reports endpoint (simple 3-table join)

## Grouped Reports Endpoint — Aggregate Design

**No SQL needed — use OutSystems Aggregate in a Server Action → Service Action wrapper**

**Inputs:** `MaxtelAppId`, `BusinessUserId`

**Aggregate Sources:**
1. `ReportModules` — base, filtered by `MaxtelAppId = @MaxtelAppId`
2. INNER JOIN `SupportedReport` on `SupportedReport.Id = ReportModules.SupportedReportId`, filtered by `Is_Active = True`
3. LEFT JOIN `ReportFavourites` on `ReportFavourites.SupportedReportId = SupportedReport.Id` AND `ReportFavourites.BusinessUserId = @BusinessUserId`

**Output Columns:**
- `SupportedReport.Id` — report identifier
- `SupportedReport.StructureName` — display name on card
- `SupportedReport.Description` — shown via info (i) button
- `SupportedReport.SmartReportTypeUniqueName` — for routing
- `ReportFavourites.Id <> NullIdentifier()` — computed as `IsFavourite` (boolean)

**Sort:** `SupportedReport.StructureName` ASC

**Pattern:**
```
Report_CS module:
├─ Server Action: GetReportsForModule (Private)
│   ├─ Input: MaxtelAppId, BusinessUserId
│   ├─ Aggregate: joins ReportModules → SupportedReport → ReportFavourites
│   └─ Output: List of reports with IsFavourite flag
└─ Service Action: GetReportsForModule (Public) ← wrapper
```

## Queries Created (test/reference only)
- `queries/reports/grouped-reports/tests/test-distinct-modules.sql` — get distinct Module values
- `queries/reports/grouped-reports/tests/test-maxtelapp-list.sql` — get all MaxtelApp rows
- `queries/reports/grouped-reports/tests/test-admin-review-reports.sql` — identify Admin Review reports
- `queries/reports/grouped-reports/tests/test-seed-report-modules.sql` — reference seed query (not for production)

## Outstanding Service Studio Work
1. Add composite unique index on ReportModules (`SupportedReportId`, `MaxtelAppId`)
2. Create ReportFavourites entity — Id, SupportedReportId (FK), BusinessUserId (Long Integer) + composite unique index
3. Add `Description` field to SupportedReport (nullable Text)
4. Build GetReportsForModule Server Action with Aggregate
5. Wrap in Service Action

## Notes for Next Session
- Report Settings frontend already built — handles module assignments + descriptions
- Module assignments use new groupings (Daily Shift, Schedules, etc.) not old Module values
- No cross-service FK constraints between Report_CS and Access_CS
- "Admin Review" module has no MaxtelApp match — reports appear moved to Daily Shift in new UI
- Favourite toggle is entity action logic (INSERT/DELETE) — no SQL needed
