# Session: Report Settings Screen — 2026-05-12

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_workitems/edit/3788
**PRD:** See prd.md in this folder (Feature 2.1.4)
**Mock:** See screenshot in session — settings table with module chips

## Original Story/Requirements

> A support-only settings screen will allow report module assignments to be managed.
>
> - Support-only nav item (wrench icon) in the Reports sidebar opens the settings screen
> - Module assignments shown as chips per report; clicking a chip ✕ removes the assignment
> - An "+ Add" link opens a dropdown of available modules; selecting one adds the assignment
> - Changes create or delete ReportModules rows immediately (no save button)
> - Description field removed — not editable in UI

## Status
- [x] In Testing
- Settings screen built and functional
- Module chip add/remove working
- Pending: user testing confirmation

## Dependencies
- **Story #3786** (complete) — ReportModules + ReportFavourites tables
- **Story #3787** (in progress) — Report Module UI (sidebar nav, card grid)

## Tables Involved
- `SupportedReport` (Report_CS) — EXISTING — Id (TEXT = display name), Is_Active
- `ReportModules` (Report_CS) — EXISTING — SupportedReportId, MaxtelAppId
- `MaxtelApp` (Access_CS) — EXISTING — Id, Name

## What Was Built

### Backend (Report_CS)

**Server/Service Actions:**

1. **AddReportModule** — assigns a report to a module
   - Input: SupportedReportId (Text), MaxtelAppId (Long Integer)
   - Logic: Check if (SupportedReportId, MaxtelAppId) already exists → if not, CreateReportModules
   - If already exists → silently skip (no exception)

2. **RemoveReportModule** — removes a module assignment
   - Input: ReportModulesId (Long Integer)
   - Logic: DeleteReportModules entity action

### Frontend (Report_UI)

**Block: ReportSettings**

**Data Actions (single Data Action, three aggregates):**
1. `Reports` — SupportedReport WHERE Is_Active = True, Sort by Id ASC
2. `ReportModules` — ReportModules JOIN MaxtelApp ON MaxtelAppId = Id, Sort by Name ASC
3. `AllModules` — MaxtelApp, Sort by Name ASC

**Separate Data Action:**
4. `FetchAvailableModules` — MaxtelApp WITH OR WITHOUT ReportModules (WHERE ReportModules.SupportedReportId = ShowDropdownForReportId), Filter: ReportModules.Id = NullIdentifier(). Depends on ShowDropdownForReportId.

**Local Variables:**
- ShowDropdownForReportId (Text) — which report's dropdown is open

**Widget Tree:**
- Table/DataGrid with columns: Report (expression), Description (display only), Modules (custom)
- Modules column: chip list + "+ Add" link + dropdown overlay
- Chips use `display: contents` CSS trick to flow inline inside OutSystems list wrappers
- "+ Add" toggles ShowDropdownForReportId → shows/hides dropdown list
- Dropdown is a Link List (not OutSystems Dropdown widget — avoids OnChange bugs)
- Transparent overlay behind dropdown catches outside clicks to close

**Client Actions:**
1. **ToggleDropdown** — toggles ShowDropdownForReportId for the current row
2. **OnModuleClicked** — calls AddReportModule → closes dropdown → refreshes data
3. **RemoveChip** — calls RemoveReportModule → refreshes data
4. **CloseDropdown** — sets ShowDropdownForReportId = "" (overlay click)

### CSS Classes

```css
.rs-modules {
    display: flex !important;
    flex-wrap: wrap !important;
    align-items: center !important;
    gap: 4px;
    position: relative;
}
.rs-modules * {
    display: contents;
}
.module-chip {
    display: inline-flex !important;
    align-items: center;
    gap: 4px;
    background: #e0f0fa;
    color: #0e5c7a;
    border-radius: 3px;
    padding: 2px 6px 2px 8px;
    font-size: 11px;
    font-weight: 600;
    white-space: nowrap;
}
.chip-remove {
    display: inline !important;
    cursor: pointer;
    color: #5a9bb8;
    font-size: 10px;
    line-height: 1;
    padding: 1px;
    border-radius: 2px;
}
.chip-remove:hover {
    color: #c62828;
}
.chip-add {
    display: inline-flex !important;
    align-items: center;
    padding: 2px 8px;
    border: 1px dashed #aaa;
    border-radius: 3px;
    font-size: 11px;
    color: #666;
    cursor: pointer;
    white-space: nowrap;
}
.chip-add:hover {
    border-color: #4a7cc9;
    color: #4a7cc9;
}
.chip-dropdown-overlay {
    display: block !important;
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    z-index: 9;
    background: transparent;
}
.chip-dropdown {
    display: block !important;
    position: absolute;
    top: 100%;
    left: 0;
    z-index: 10;
    background: #fff;
    border: 1px solid #e0e0e0;
    border-radius: 3px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    min-width: 150px;
    margin-top: 4px;
    padding: 2px 0;
}
.chip-dropdown * {
    display: contents;
}
.chip-dropdown-item {
    display: block !important;
    padding: 6px 12px;
    font-size: 12px;
    color: #333;
    cursor: pointer;
    white-space: nowrap;
}
.chip-dropdown-item:hover {
    background: #f0f0f0;
}
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
- **Description removed** — not editable in UI, managed directly in DB if needed
- **Save button removed** — chip add/remove are immediate server calls
- **Link List instead of OS Dropdown** — Dropdown widget had OnChange bugs (firing on initial render, shared variable across rows)
- **display: contents CSS trick** — makes OutSystems list wrappers invisible to flexbox
- **Overlay for outside-click** — transparent fixed overlay catches clicks to close dropdown
- **FetchAvailableModules** — separate Data Action filtered by ShowDropdownForReportId, excludes already-assigned modules for that report
- **Wrench icon in sidebar** — support-only nav item using fa-wrench

## Resolved Issues
1. ~~OutSystems Dropdown shared variable~~ — replaced with Link List
2. ~~OnChange firing on initial render~~ — eliminated by using Link OnClick instead
3. ~~Chips stacking vertically~~ — fixed with `display: contents` on wrappers
4. ~~"(Unassigned)" chips~~ — caused by bad data in DB (MaxtelAppId = 0), cleaned up

## Next Steps
1. User testing confirmation
2. Style refinements if needed

## Known User IDs
- Abdul Haseeb: BusinessUserId = 317646, HomeSiteId = 3187
