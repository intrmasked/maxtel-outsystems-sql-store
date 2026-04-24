# Reports — PRD

**Epic ID:** 2.0
**Author:** Daniel
**Updated:** 2026-04-23

---

## Overview

The Reports epic reorganises Maxtel Manager's reports module to make reports easier to discover and access. Reports are grouped by operational module, users can mark favourites for quick access, and a printer-button slide-over provides rapid navigation from anywhere in the app.

## Features

| ID  | Feature                              | Status |
|-----|--------------------------------------|--------|
| 2.1 | Reports Module                       | Draft  |
| 2.2 | Report Favourites & Quick Access     | Draft  |

## User Roles

| Role    | Access                                              |
|---------|-----------------------------------------------------|
| Manager | Full access to all report categories                |
| Staff   | Access to reports relevant to their operational role |

## Shared Business Rules

| Rule                        | Detail                                                                 |
|-----------------------------|------------------------------------------------------------------------|
| Sales Ledger retired        | The Sales Ledger report is not included in the reorganised module       |
| Module visibility           | Only modules that contain at least one report are shown in the left nav |
| Smart Reports / My Reports  | Existing shortcuts retained as header buttons on the Reports screen     |

---

## Feature 2.1: Reports Module

Reports are reorganised from a flat list into named module groups, with a left-side navigation menu and a two-column card layout per group.

### User Stories

**2.1.1: Browse reports by module**
- Left nav lists all modules that contain at least one report
- Selecting a module shows its reports in a two-column card grid
- Active module is visually highlighted

**2.1.2: View a report description**
- Each report card has an info (i) button
- Hovering displays a short description of the report

**2.1.3: Open a report from the module view**
- Click a report card → parameter form slides open to configure and run the report

**2.1.4: Manage report module assignments (Support)**
- Accessible via a Settings screen within Reports (support-only)
- Lists all SupportedReports with their current module assignments
- Module assignments editable via checkboxes (report may be assigned to multiple modules)
- Report description is editable inline

### Business Rules

| Rule              | Detail                                                                    |
|-------------------|---------------------------------------------------------------------------|
| Report grouping   | A report may be assigned to one or more module groups via ReportModules    |
| Report order      | Within a module, reports ordered by Maxtel design (not user-configurable)  |
| Module visibility | Only modules with at least one assigned report appear in the left nav      |
| Settings access   | Support-only, not visible to standard users                               |
| Access            | A required role is associated with each report; only users with that role can access |

### Out of Scope
- User-defined report ordering within a module
- User-defined module groupings

---

## Feature 2.2: Report Favourites & Quick Access

Users can mark individual reports as favourites. Favourites are surfaced in a quick-access slide-over panel triggered by the printer icon in the sidebar.

### User Stories

**2.2.1: Favourite a report**
- Star icon on each report card (unfilled = not favourite, filled = favourite)
- Clicking the star toggles the favourite state
- No limit on number of favourites
- Favourites stored per login

**2.2.2: Access favourites from the slide-over**
- Printer icon in sidebar header opens the slide-over
- Left panel shows module category links + favourited reports below a divider
- Clicking a module link navigates to that module in Reports screen, closes slide-over
- Clicking a favourited report highlights it, shows parameter form in right panel

### Business Rules

| Rule               | Detail                                                  |
|--------------------|---------------------------------------------------------|
| Favourite storage  | Stored per login, not per site or per role              |
| No limit           | No maximum number of favourited reports                 |

---

## Technical Design

### Architecture

```
Report_UI → Report_CS → Access_CS
              │              │
              │              ├─ MaxtelApp
              │              └─ BusinessUser
              │
              ├─ SupportedReport
              ├─ ReportModules
              └─ ReportFavourites
```

- **Report_CS** owns SupportedReport, ReportModules, and ReportFavourites
- **Access_CS** owns MaxtelApp and BusinessUser (referenced by ID, no cross-service FK constraints)

### Data Model

**SupportedReport (Report_CS — modified)**
- Module field removed
- Description field added (nullable string, displayed via info button)

**ReportModules (Report_CS — new)**
- Many-to-many join between SupportedReport and MaxtelApp
- MaxtelAppId stored by value; no cross-service FK
- Composite unique constraint on (SupportedReportId, MaxtelAppId)
- A report may be assigned to more than one module

**ReportFavourites (Report_CS — new)**
- Links SupportedReport to BusinessUser
- BusinessUserId stored by value; no cross-service FK
- Composite unique constraint on (SupportedReportId, BusinessUserId)

### Key Logic

**Module screen and slide-over load:**
1. Resolve current MaxtelAppId from session context
2. Fetch all SupportedReports that have a ReportModules row for this MaxtelAppId
3. Group reports by module (via ReportModules) for left-nav rendering
4. Resolve current BusinessUserId from session context
5. Fetch all ReportFavourites rows for this BusinessUserId
6. Mark each report card starred where SupportedReportId appears in the favourites set

**Favourite toggle:**
- If ReportFavourites(SupportedReportId, BusinessUserId) exists → DELETE
- Else → INSERT
- Optimistically update star state in UI; revert on error
