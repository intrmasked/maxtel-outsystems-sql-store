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
- Backend endpoints built and working
- UI blocks built, cards rendering, grid working
- Active state on sidebar nav — FIXED
- Initial load auto-select first module — FIXED
- Pending: favourite toggle testing, style refinements

## Dependencies
- **Story #3786** (complete) — GetReportsForModule endpoint, ReportModules + ReportFavourites tables

## What Was Built

### Backend (Report_CS)

**Server/Service Actions:**

1. **GetReportModuleList** — returns module list with report counts
   - Structure: `ReportModuleItem` (MaxtelAppId, ModuleName, ReportCount)
   - Aggregate: ReportModules → Only With SupportedReport (Is_Active=True) → Only With MaxtelApp
   - Group By: MaxtelApp.Id, MaxtelApp.Name, Count SupportedReport.Id

2. **GetReportsForModule** — returns reports for a module with favourite status
   - Structure: `ReportForModule` (SupportedReportId, ReportName, SmartReportTypeUniqueName, IsFavourite)
   - Input: MaxtelAppId, BusinessUserId
   - Aggregate: ReportModules → Only With SupportedReport → With or Without ReportFavourites
   - **ReportName = SupportedReport.Id** (Id is TEXT type, contains the display name)

3. **ToggleReportFavourite** — toggle favourite on/off
   - Input: SupportedReportId, BusinessUserId
   - Finds existing ReportFavourites row → if exists DELETE, else CREATE
   - Output: ToggleFavouriteResult (IsFavourite, Success)

**Data seeded:**
- ReportModules: 18 rows mapping old Module values to MaxtelApp IDs
- Seeded via INSERT query (test-insert-report-modules.sql)

### Frontend (Report_UI)

**Screen: ReportsHome**
- Layout: Common\Layout_V4
- MenuNavigation / NavOptions: ReportsMenu block (sidebar)
- MainContent: ReportsHomeNew block (content area)
- Input params: MaxtelAppId, ModuleName — passed to both ReportsMenu and ReportsHomeNew
- On initial load with no params: ReportNav auto-selects first module via OnAfterFetch

**Block: ReportsMenu (sidebar wrapper)**
- Input params: ActiveMaxtelAppId (Long Integer), ActiveModuleName (Text)
- Contains: ReportNav block + Settings nav link (wrench icon)
- ReportNavOnModuleSelected handler: navigates to ReportsHome with MaxtelAppId + ModuleName params

**Block: ReportNav (sidebar nav list)**
- Input param: ActiveMaxtelAppId (Long Integer)
- Data Action: FetchReportModuleList → GetReportModuleList service action
- List → Link with Style Classes: `If(Current.MaxtelAppId = ActiveMaxtelAppId, "menu-item active", "menu-item")`
- OnClick → triggers OnModuleSelected event
- **OnAfterFetch**: if ActiveMaxtelAppId = 0, fires OnModuleSelected with List[0] to auto-select first module

**Block: ReportHome (card grid)**
- Input: MaxtelAppId, ModuleName, BusinessUserId
- Data Action: FetchReports (depends on MaxtelAppId) → calls GetReportsForModule
- Header: ModuleName + "(" + ReportCount + ")"
- Container class: `report-card-grid` with List inside
- Each list item = ReportCard block

**Block: ReportCard**
- Input: SupportedReportId, ReportName, IsFavourite, BusinessUserId
- Events: OnReportClick(SupportedReportId)
- Local var: IsFav (optimistic toggle)
- Star: If widget swapping `star` (filled) / `star-o` (outline) icons
- ToggleFavourite: optimistic flip → call ToggleReportFavourite service action → revert on failure

### CSS Classes

**Report Card Grid:**
```css
.report-card-grid {
    display: block;
}
.report-card-grid > .list {
    display: grid !important;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
}
.report-card-grid > .list > .OSBlockWidget {
    min-width: 0;
}
.report-card-grid > .list > script {
    display: none !important;
}
```

**Report Card:**
```css
.report-card {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    border: 1px solid #e0e0e0;
    border-radius: 6px;
    cursor: pointer;
    background: #fff;
    transition: box-shadow 0.15s ease;
}
.report-card:hover {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}
.report-card-left {
    display: flex;
    align-items: center;
    gap: 10px;
}
.report-card-star {
    display: flex;
    align-items: center;
    font-size: 16px;
    color: #ccc;
    cursor: pointer;
    padding: 4px;
}
.report-card-star.is-fav {
    color: #f5a623;
}
.report-card-name {
    font-size: 14px;
    font-weight: 500;
    color: #333;
}
.report-card-info {
    font-size: 16px;
    color: #4a7cc9;
    cursor: pointer;
    padding: 4px;
}
```

**Sidebar Nav:**
```css
.report-nav {
    display: flex;
    flex-direction: column;
}
.report-nav > .list {
    display: flex !important;
    flex-direction: column;
}
.report-nav > .list > script {
    display: none !important;
}
```

**Utility:**
```css
.link-no-style,
.link-no-style:hover,
.link-no-style:active,
.link-no-style:focus,
.link-no-style:visited {
    text-decoration: none !important;
    border-bottom: none !important;
    box-shadow: none !important;
    outline: none !important;
    color: inherit !important;
}
```

## Key Decisions
- **SupportedReport.Id is TEXT** — contains the report display name, not an auto-number
- **Description removed** — no longer shown on report cards or settings
- **Sidebar uses existing menu-item/active classes** — no custom nav styling needed
- **Favourite toggle via Server/Service Action** — not raw entity actions from UI
- **Optimistic UI** — star flips immediately, reverts on failure
- **Grid CSS targets .list child** — OutSystems list wrapper sits between grid container and items
- **No font-awesome** — using OutSystems default icon library (star/star-o, info-circle)
- **ActiveMaxtelAppId as Input Parameter** on ReportsMenu and ReportNav — not local var (fixes active class issue)
- **Auto-select first module** — ReportNav OnAfterFetch fires OnModuleSelected with List[0] when ActiveMaxtelAppId is 0

## Resolved Issues
1. ~~**Active class on sidebar not updating**~~ — FIXED: Changed ActiveMaxtelAppId from local variable to Input Parameter on ReportsMenu and ReportNav. Screen binds its input params to these inputs.
2. ~~**Empty screen on initial load**~~ — FIXED: ReportNav OnAfterFetch auto-selects first module when no module specified.

## Next Steps
1. Test favourite toggle with ToggleReportFavourite service action
2. Style refinements to match mock

## Known User IDs
- Abdul Haseeb: BusinessUserId = 317646, HomeSiteId = 3187
