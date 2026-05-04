# Session: Report Module UI — 2026-04-26

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_workitems/edit/3787
**PRD:** See prd.md in this folder
**Mock:** _(see screenshot in session — Daily Shift module view with 10 report cards)_

## Original Story/Requirements

> The Reports module will be rebuilt with a module specific navigation in the sidebar and updated
> - Menu bar renders module groups from the API; only modules with assigned reports are shown, each with a report count
> - Two-column card grid for the active module — each card shows a star and an info tooltip displaying Description
> - Report slideover is maintained

## Status
- [ ] In Progress
- Endpoint designs complete, block designs complete, building in Service Studio

## Dependencies
- **Story #3786** (complete) — GetReportsForModule endpoint, ReportModules + ReportFavourites tables

## What Was Built

### Endpoints (Report_CS — Aggregates, no SQL)

**1. GetReportModuleList** — Sidebar module list
> Returns the list of report modules for the sidebar navigation. Each item contains the module name, its MaxtelAppId, and the count of active reports assigned to it. Only modules with at least one active report are returned.

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
> Returns all active reports assigned to a given module. Takes a MaxtelAppId (from the sidebar selection) and a BusinessUserId (logged-in user) to determine each report's favourite status. Each item contains the report name, description, routing key, and whether the user has favourited it.

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

---

### UI Blocks (Report_UI)

**Block 1: ReportModuleNav** — Sidebar module list

**Location**: `Report_UI / UI Flows / Common / ReportModuleNav`

**Inputs**: _none_ — sidebar list is user-agnostic (same modules/counts for everyone). Parent screen owns `BusinessUserId` and pairs it with the `MaxtelAppId` from `OnModuleSelected` when calling `GetReportsForModule`.

**Events**

| Name | Parameters | Description |
|---|---|---|
| `OnModuleSelected` | `MaxtelAppId` (Long Integer), `ModuleName` (Text) | Fires on initial auto-select AND every click |

**Local Variables**

| Name | Type | Default | Description |
|---|---|---|---|
| `ActiveMaxtelAppId` | Long Integer | `0` | Currently selected — drives highlight |
| `ActiveModuleName` | Text | `""` | Echoed in `OnModuleSelected` |

**Data Action**: `GetReportModuleList` (Service Action from Report_CS) — Cache = 0 (counts can change)

**Widget Tree**
```
Container [Class: "report-module-nav"]
│
├─ Container [Class: "nav-header"]
│   └─ Text "Reports"
│
├─ If [GetReportModuleList.List.Length = 0 AND NOT IsDataFetched]    ← LOADING
│   └─ Container [Class: "nav-loading"] → Text "Loading..."
│
├─ If [IsDataFetched AND List.Length = 0]                            ← EMPTY
│   └─ Container [Class: "nav-empty"] → Text "No reports available"
│
└─ If [List.Length > 0]
    └─ List [Source: GetReportModuleList.List, Class: "nav-list"]
        │
        └─ Container [Class: "nav-item " +
                              If(Current.MaxtelAppId = ActiveMaxtelAppId,
                                 "active-module", "")]
            │   OnClick: SelectModule (Ajax Submit, no confirmation)
            │
            ├─ Text [Value: Current.ModuleName, Class: "nav-item-name"]
            └─ Container [Class: "nav-item-badge"]
                └─ Text [Value: Current.ReportCount]
```

**Client Action: `SelectModule`** (no inputs — reads `Current` from List)
```
Assign  ActiveMaxtelAppId = GetReportModuleList.List.Current.MaxtelAppId
        ActiveModuleName  = GetReportModuleList.List.Current.ModuleName
Trigger OnModuleSelected(ActiveMaxtelAppId, ActiveModuleName)
```

**OnAfterFetch (on GetReportModuleList)** — auto-select first module
```
If List.Length > 0 AND ActiveMaxtelAppId = NullIdentifier()
  ├─ Assign ActiveMaxtelAppId = List[0].MaxtelAppId
  ├─ Assign ActiveModuleName  = List[0].ModuleName
  └─ Trigger OnModuleSelected(ActiveMaxtelAppId, ActiveModuleName)
```

> **Why the `NullIdentifier()` guard?** Prevents re-firing `OnModuleSelected` if the data action re-fetches — once a module is active, don't clobber the user's selection.

**CSS** (block's Style Sheet)
```css
.report-module-nav { display: flex; flex-direction: column; width: 240px;
    padding: 16px 0; border-right: 1px solid var(--color-neutral-4);
    background: var(--color-neutral-1); }
.nav-header { padding: 0 16px 12px 16px; font-size: 18px; font-weight: 600;
    color: var(--color-neutral-9); }
.nav-loading, .nav-empty { padding: 16px; color: var(--color-neutral-7);
    font-style: italic; }
.nav-list { display: flex; flex-direction: column; }
.nav-item { display: flex; justify-content: space-between; align-items: center;
    padding: 10px 16px; cursor: pointer; border-left: 3px solid transparent;
    transition: background 0.12s, border-color 0.12s; }
.nav-item:hover { background: var(--color-neutral-3); }
.nav-item.active-module { background: var(--color-neutral-4);
    border-left-color: var(--color-primary); font-weight: 600; }
.nav-item-name { flex: 1; color: var(--color-neutral-9); }
.nav-item-badge { background: var(--color-neutral-5); color: var(--color-neutral-9);
    border-radius: 12px; padding: 2px 10px; font-size: 12px; font-weight: 500;
    min-width: 24px; text-align: center; }
.nav-item.active-module .nav-item-badge { background: var(--color-primary); color: white; }
```

**Build Checklist**
1. Create block in `Report_UI / Common / ReportModuleNav`
2. Add event `OnModuleSelected(MaxtelAppId: Long Integer, ModuleName: Text)`
3. Add local vars `ActiveMaxtelAppId`, `ActiveModuleName`
4. Manage Dependencies → Report_CS → tick `GetReportModuleList`
5. Drop Data Action `GetReportModuleList`, Cache = 0
6. Build widget tree
7. Wire `OnAfterFetch` → auto-select logic
8. Wire `OnClick` of `nav-item` → `SelectModule`
9. Paste CSS into Style Sheet tab
10. Publish

**Status**: Spec finalized 2026-04-30 — ready to build in Service Studio

---

**Block 2: ReportCard** — Individual report card item

| Input | Type | Mandatory | Description |
|---|---|---|---|
| SupportedReportId | Long Integer | Yes | Report ID |
| ReportName | Text | Yes | Display name |
| Description | Text | No | Info tooltip text |
| IsFavourite | Boolean | Yes | Star filled or not |
| BusinessUserId | Long Integer | Yes | For favourite toggle |

| Event | Parameters | Description |
|---|---|---|
| OnReportClick | SupportedReportId | Card clicked — open report |
| OnFavouriteChanged | SupportedReportId, IsFavourite | Star toggled |

| Local Variable | Type | Description |
|---|---|---|
| IsFav | Boolean | Local copy for optimistic UI |

Initialize:
- Set IsFav = IsFavourite (copy input to local)

Card Click:
- Trigger OnReportClick(SupportedReportId)

Star Click (handled inside block):
```
ToggleFavourite
├─ Set IsFav = NOT IsFav  (optimistic — star flips immediately)
├─ If IsFav = True
│   ├─ CreateReportFavourites(SupportedReportId, BusinessUserId)
│   └─ On Error → revert IsFav
├─ Else
│   ├─ Aggregate: find ReportFavourites row by SupportedReportId + BusinessUserId
│   ├─ DeleteReportFavourites(row.Id)
│   └─ On Error → revert IsFav
├─ Trigger OnFavouriteChanged(SupportedReportId, IsFav)
```

Layout:
```
Card Container (clickable → CardClicked)
├─ Star Icon (clickable → ToggleFavourite, STOP PROPAGATION)
│   └─ If IsFav: filled star (gold) / Else: outline star (grey)
├─ Report Name (text)
└─ Info Icon (i) → Tooltip: Description
```

---

### Full Page Assembly (Reports Screen)

```
Reports Screen
│
├─ Header: ModuleName (ReportCount) + "Smart Reports" / "My Reports" buttons
│
├─ Sidebar: ReportModuleNav Block
│   └─ OnModuleSelected →
│       ├─ Call GetReportsForModule(MaxtelAppId, BusinessUserId)
│       └─ Update card grid
│
├─ Main Content: 2-column grid (List Widget)
│   └─ For each report:
│       ReportCard Block
│       ├─ Inputs: SupportedReportId, ReportName, Description, IsFavourite, BusinessUserId
│       ├─ OnReportClick → open report slideover/parameter form
│       └─ OnFavouriteChanged → (optional refresh)
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
- **Separated report-control from reports** — `queries/report-control/` for UI/backend, `queries/reports/` for actual reports
- **No SQL needed** — both endpoints use Aggregates
- **Favourite toggle inside ReportCard block** — block handles entity actions + optimistic UI
- **Stop propagation on star click** — prevents card click from firing when toggling favourite
- **Slideover maintained** — no changes to existing slideover behaviour

## Known User IDs
- Abdul Haseeb: BusinessUserId = 317646, HomeSiteId = 3187
