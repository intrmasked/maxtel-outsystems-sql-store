# Session: Report Settings UI Fixes - 2026-05-23

## Issues Addressed

### 1. AddReportModule — Missing ConceptId Filter
**Problem**: The `CheckExists` aggregate in `AddReportModule` server action only filters on `SupportedReportId` and `MaxtelAppId`. If Concept A already has Report X + Module Y, adding the same combo for Concept B gets skipped because CheckExists finds the existing row.

**Fix (OutSystems)**:
- Add `ConceptId` as an input parameter on `AddReportModule` (server action + service action wrapper)
- Add third filter to `CheckExists` aggregate:
  ```
  ReportModules.SupportedReportId = SupportedReportId
  and ReportModules.MaxtelAppId = MaxtelAppId
  and ReportModules.ConceptId = ConceptId
  ```
- Ensure `CreateReportModule` entity action also sets `ConceptId` on the record

**Status**: Fix identified, user to implement in OutSystems

### 2. SlideOver Panel — Inconsistent Width When List Is Empty
**Problem**: The container holding the report list (inside Tabs) collapses to text width when the list has no items. When items are present, it stretches to fill. Causes inconsistent panel width.

**Attempts that didn't work**:
- `width: 100%` on the list container — no effect (parent placeholder can't be styled)
- `align-self: stretch` — no effect
- `width: 100%` on All Reports container — no effect

**Fix (OutSystems)**:
- Set `min-width: 300px` (or appropriate value) on the container to force consistent width
- Add `overflow-x: hidden` on the parent that shows the horizontal scrollbar (SlideOver content area or Tabs wrapper) to suppress the scrollbar caused by min-width

**Status**: Fix identified, user to implement in OutSystems

## Notes
- Both fixes are pure OutSystems UI changes — no SQL involved
- No code changes in this repo

## Status
- [X] Complete
