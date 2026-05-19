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
- [x] Complete
- Settings screen built and functional
- Module chip add/remove working
- DataGrid replaced with List + CSS grid layout (resolved all script/layout issues)
- Overlay replaced with JS document listener (resolved scroll blocking)
- Dropdown flips upward when near bottom of viewport
- Dropdown has max-height with internal scroll
- User confirmed working 2026-05-19

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

**Widget Tree (Final — List + CSS Grid, no overlay):**
```
Container (class: "settings-table")
├── Container (class: "settings-header")
│   ├── Container → Text "Report"
│   └── Container → Text "Modules"
└── List (Source: Reports)
    └── Container (class: "settings-row")
        ├── Expression (class: "settings-cell-name")
        └── Container (class: "rs-modules")
            ├── List (Source: filtered ReportModules)
            │   └── Container (class: "module-chip")
            │       ├── Expression: Name
            │       └── Link (class: "chip-remove link-no-style") → RemoveChip
            └── Container (class: "chip-add-wrapper")
                ├── Link (class: "chip-add link-no-style") → ToggleDropdown
                │   └── Text "+ Add"
                └── If (ShowDropdownForReportId = Current)
                    └── Container (class: "chip-dropdown")
                        └── List (Source: FetchAvailableModules)
                            └── Link (class: "chip-dropdown-item link-no-style") → OnModuleClicked
                                └── Expression: Name
```

**Client Actions:**
1. **ToggleDropdown** — toggles ShowDropdownForReportId for the current row + JS node for flip detection and outside-click listener
2. **OnModuleClicked** — calls AddReportModule → closes dropdown → refreshes data
3. **RemoveChip** — calls RemoveReportModule → refreshes data
4. **CloseDropdown** — sets ShowDropdownForReportId = "" + JS node to remove document listener

**JavaScript in ToggleDropdown (after setting ShowDropdownForReportId):**
```javascript
setTimeout(function() {
    var dropdown = document.querySelector('.chip-dropdown');
    if (!dropdown) return;

    var rect = dropdown.getBoundingClientRect();
    if (rect.bottom > window.innerHeight) {
        dropdown.classList.add('flip-up');
    }

    function closeOnOutsideClick(e) {
        if (!e.target.closest('.chip-add-wrapper')) {
            document.removeEventListener('mousedown', closeOnOutsideClick, true);
            $actions.CloseDropdown();
        }
    }

    document.removeEventListener('mousedown', window._rsCloseDropdown, true);
    window._rsCloseDropdown = closeOnOutsideClick;
    document.addEventListener('mousedown', closeOnOutsideClick, true);
}, 50);
```

**JavaScript in CloseDropdown:**
```javascript
document.removeEventListener('mousedown', window._rsCloseDropdown, true);
window._rsCloseDropdown = null;
```

### CSS Classes (Final)

```css
.settings-table {
    width: 100%;
    border: 1px solid #e0e0e0;
    border-radius: 4px;
}

.settings-table > * {
    display: contents !important;
}

.settings-header {
    display: grid !important;
    grid-template-columns: 200px 1fr;
    column-gap: 24px;
    background: #f5f5f5;
    font-weight: 600;
    font-size: 12px;
    color: #666;
    padding: 10px 16px;
    border-bottom: 2px solid #e0e0e0;
}

.settings-row {
    display: grid !important;
    grid-template-columns: 200px 1fr;
    column-gap: 24px;
    align-items: start;
    padding: 12px 16px;
    border-bottom: 1px solid #e0e0e0;
    min-height: 44px;
}

.settings-row:last-child {
    border-bottom: none;
}

.settings-cell-name {
    font-weight: 500;
    font-size: 13px;
    color: #333;
    padding-top: 4px;
}

.rs-modules {
    display: flex !important;
    flex-wrap: wrap !important;
    align-items: center !important;
    justify-content: flex-start !important;
    gap: 6px;
    width: 100%;
}

.rs-modules * {
    display: contents !important;
}

.rs-modules .module-chip {
    display: inline-flex !important;
    align-items: center;
    gap: 4px;
    background: #e0f0fa;
    color: #0e5c7a;
    border-radius: 3px;
    padding: 4px 8px 4px 10px;
    font-size: 11px;
    font-weight: 600;
    white-space: nowrap;
    flex-shrink: 0;
}

.rs-modules .chip-remove {
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

.rs-modules .chip-add-wrapper {
    display: inline-flex !important;
    position: relative;
    flex-shrink: 0;
}

.rs-modules .chip-add {
    display: inline-flex !important;
    align-items: center;
    padding: 4px 10px;
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

.rs-modules .chip-dropdown {
    display: block !important;
    position: absolute;
    top: 100%;
    left: 0;
    z-index: 10;
    background: #fff;
    border: 1px solid #e0e0e0;
    border-radius: 3px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    min-width: 180px;
    max-height: 200px;
    overflow-y: auto;
    margin-top: 4px;
    padding: 4px 0;
}

.rs-modules .chip-dropdown.flip-up {
    top: auto;
    bottom: 100%;
    margin-top: 0;
    margin-bottom: 4px;
}

.rs-modules .chip-dropdown * {
    display: block !important;
}

.rs-modules .chip-dropdown-item {
    display: block !important;
    padding: 8px 12px;
    font-size: 12px;
    color: #333;
    cursor: pointer;
    white-space: nowrap;
}

.chip-dropdown-item:hover {
    background: #f0f0f0;
}
```

**Note:** `.link-no-style` class is shared/global — not repeated here.

### CSS Strategy Explained

**Why `!important`:**
OutSystems injects inline styles (`style="display: flex"`) on List/If widgets.
Normal CSS classes cannot override inline styles — `!important` is the only way.

**Why `.rs-modules *` with `display: contents`:**
OutSystems wraps every widget in extra `<div>` containers you can't remove.
Flexbox only controls direct children, so these wrappers break chip layout.
`display: contents` makes wrapper divs invisible to layout (ghost boxes) —
children get "promoted" up to the flex parent. Then each classed element
(`.module-chip`, `.chip-add`, `.chip-dropdown`) gets its display restored
with higher specificity (`.rs-modules .class` beats `.rs-modules *`).

**Why `.rs-modules .chip-dropdown *` overrides the wildcard:**
The `.rs-modules *` rule also nukes elements inside the dropdown, breaking
its scroll container. `.rs-modules .chip-dropdown * { display: block }` restores
block layout inside the dropdown so `max-height` + `overflow-y: auto` works.

**Why JS document listener instead of overlay:**
The original overlay (`position: fixed; 100vw × 100vh`) blocked page scrolling.
A `mousedown` listener on `document` catches outside clicks without blocking scroll.
Uses `window._rsCloseDropdown` to store the listener reference so previous listeners
are cleaned up when a new dropdown opens (prevents multiple dropdowns stacking).

**Why not default OutSystems classes:**
OS provides `display-flex`, `padding-s`, etc. for simple layouts.
But OS has no class for `display: contents`, no way to remove its own wrapper divs
from layout, and no way to override its own inline styles on List/If widgets.
The moment you put a List inside a flex container and need items to flow inline,
you've left what OS classes can handle.

## Key Decisions
- **Description removed** — not editable in UI, managed directly in DB if needed
- **Save button removed** — chip add/remove are immediate server calls
- **Link List instead of OS Dropdown** — Dropdown widget had OnChange bugs (firing on initial render, shared variable across rows)
- **display: contents CSS trick** — makes OutSystems list wrappers invisible to flexbox
- **Overlay removed → JS document listener** — overlay blocked page scroll; mousedown listener on document handles outside-click without scroll blocking
- **FetchAvailableModules** — separate Data Action filtered by ShowDropdownForReportId, excludes already-assigned modules for that report
- **Wrench icon in sidebar** — support-only nav item using fa-wrench
- **DataGrid → List + CSS Grid** — DataGrid had a JS script that re-measured layout on DOM changes, causing page jumps when List widgets were inside cells. Replaced with a plain List widget styled as a table using CSS Grid. All logic stayed the same.
- **chip-add-wrapper** — wraps "+ Add" button and dropdown together so dropdown anchors directly below the button via `position: relative` on wrapper + `position: absolute` on dropdown
- **Dropdown flip-up** — JS in ToggleDropdown checks if dropdown bottom exceeds viewport height, adds `.flip-up` class to open upward instead
- **Dropdown scroll** — `max-height: 200px; overflow-y: auto` on dropdown, with `.chip-dropdown * { display: block }` to override the wildcard and restore scroll container

## Resolved Issues
1. ~~OutSystems Dropdown shared variable~~ — replaced with Link List
2. ~~OnChange firing on initial render~~ — eliminated by using Link OnClick instead
3. ~~Chips stacking vertically~~ — fixed with `display: contents` on wrappers
4. ~~"(Unassigned)" chips~~ — caused by bad data in DB (MaxtelAppId = 0), cleaned up
5. ~~DataGrid script causing page jumps~~ — replaced DataGrid with List + CSS Grid layout
6. ~~"+ Add" button on separate line~~ — `display: contents` wildcard + specificity restore pattern
7. ~~Dropdown appearing on wrong row~~ — moved dropdown inside `chip-add-wrapper` with `position: relative`
8. ~~No gap between columns~~ — added `column-gap: 24px` to grid rows and header
9. ~~Overlay blocking page scroll~~ — removed overlay, replaced with JS document mousedown listener
10. ~~Multiple dropdowns open at once~~ — mousedown fires before click, stored listener ref on window for cleanup
11. ~~Dropdown going off-screen at bottom~~ — JS flip detection adds `.flip-up` class
12. ~~Dropdown scroll resetting~~ — `.chip-dropdown * { display: block }` overrides the wildcard inside dropdown

## Known User IDs
- Abdul Haseeb: BusinessUserId = 317646, HomeSiteId = 3187
