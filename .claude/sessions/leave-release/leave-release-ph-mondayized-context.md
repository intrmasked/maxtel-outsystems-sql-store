# Session: Leave Release PH Mondayized Fix - 2026-05-24

## Original Story/Requirements

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_workitems/edit/3825
**Branch:** `story/3825-leave-release-ph-mondayized`

### Part 1: Leave Release Filter Default ✅ WORKING
When entering Leave Release week, the filter defaults to "Pending" in all cases. It should check the roster week's ScheduleStatus — if the week is **Closed** (PayweekClosed, Id=5), default to "All" instead of "Pending". This is in **Leave_UI**.

**Fix applied**: OnAfterFetch of `GetRosterWeeksBySiteId` → If `ScheduleStatusId = PayweekClosed` → set ViewType = "All" → call `ButtonGroup2OnChange`. Tested and working.

**Potential issue**: If `ButtonGroup2OnChange` refreshes everything (including `GetRosterWeeksBySiteId`), it could cause an infinite loop. If so, add an `IsInitialLoad` boolean guard. During testing it didn't loop, but watch for it.

### Part 2: PH Mondayized Badge Fix — IN PROGRESS

**Problem**: PH badge shows on both the original and Mondayized date for all employees. Should only show on the day the employee has `IsObserved = 1`.

**Root cause identified**: The bug is in **`GetHolidayLists`** server action in **RosterManagement_CS** (not in the Leave_UI Data Action).

## GetHolidayLists Server Action — Full Flow Analysis

### Inputs
- `BusinessUserId`, `WeekEndDate`, `SiteId` (and likely others)

### Data Sources
- **`GetPublicHolidaysBySiteId`** Aggregate — fetches from PublicHoliday + RosterWeekPublicHolidayReview

### Flow Logic

```
For each PH in GetPublicHolidaysBySiteId.List:
│
├── Mondayised? (MondayisedFmPublicHolidayId <> NullIdentifier())
│   │
│   ├── TRUE — This IS a Mondayized record (e.g., Mon 2 Mar)
│   │   └── GetEmployeeWeeks by BusinessUserId
│   │       └── GetParentPublicHolidayReviewById
│   │           └── Parent complete & Not Observed?
│   │               Condition: Parent.IsComplete AND NOT Parent.IsObserved
│   │               ├── TRUE → ListAppend (show Mondayized date) ✓ CORRECT
│   │               │   "Parent (Sat) is complete & employee NOT observed on Sat
│   │               │    → employee observes Mon instead → show Mon badge"
│   │               └── FALSE → back to loop (skip)
│   │
│   └── FALSE — This is NOT a Mondayized record (original or normal PH)
│       │
│       ├── Mondayisable & Past?
│       │   Condition: WeekEndDate < CurrDate()
│       │     AND IsMondayisable
│       │     AND RosterWeekPublicHolidayReview.IsComplete
│       │   │
│       │   ├── TRUE — Original date that WAS Mondayized & past week (e.g., Sat 28 Feb)
│       │   │   └── WeekEndDate < CurrDateTime converted to local?
│       │   │       ├── TRUE → GetParentPublicHolidayReviewById
│       │   │       │   └── Parent complete & Not Observed?
│       │   │       │       Condition: IsComplete AND NOT IsObserved
│       │   │       │       ├── TRUE → ListAppend ← 🐛 BUG IS HERE
│       │   │       │       │   "NOT observed on Sat → should SKIP Sat, not show it"
│       │   │       │       └── FALSE → back to loop
│       │   │       └── FALSE → back to loop
│       │   │
│       │   └── FALSE — Normal PH (not Mondayisable) → ListAppend directly
│       │
```

### The Bug — True/False Swapped on Mondayisable Path

For the **Mondayised = True** path (checking the Mondayized Mon record):
- `Parent complete & NOT observed on parent (Sat)` → **Append** Mon ✓ correct
- "If you don't observe Sat, show Mon"

For the **Mondayisable & Past = True** path (checking the original Sat record):
- `IsComplete & NOT IsObserved on Sat` → **Append** Sat ✗ **WRONG**
- "If you don't observe Sat, show Sat anyway" — should SKIP, not append
- The True/False outcomes need to be **swapped** for this path

### Proposed Fix
On the Mondayisable & Past path, at the `Parent complete & Not Observed?` check:
- **TRUE** (complete & NOT observed) → **back to loop** (skip — employee observes the Mondayized day instead)
- **FALSE** (observed on this day) → **ListAppend** (show badge — employee observes the original day)

### Open Question
Is the `Parent complete & Not Observed?` the **same If node** reused for both paths, or are they separate If nodes? If same node, you can't just swap the branches — you'd need to create a separate If for the Mondayisable path.

## Status
- [ ] Complete / [x] In Progress / [ ] Needs Review

## Tables Documentation Created (ALL VERIFIED FROM ENTITY SCREENSHOTS)
- `database-context/tables/PublicHolidayReview/` - NEW — key columns: EmployeeWeekId, HolidayDate, IsObserved, IsEntitledBySystem, IsEntitledByOverride, RosterWeekPHReviewId
- `database-context/tables/EmployeeWeek/` - NEW — key columns: BusinessUserId, WeekEndDate, AMH, EmployeeWeekStatusId, IsSchoolOrUniHoliday, HasLeaveApplied
- `database-context/tables/PublicHoliday/` - NEW — key columns: Name, Date, CountryCode, ProvinceId, IsMondayisable, MondayisedFmPublicHolidayId (self-ref FK)
- `database-context/tables/RosterWeek/` - NEW — key columns: SiteId, StartDate, EndDate, ScheduleStatusId, ManagersRosterStatusId, CrewRosterStatusId, IsSandBox, PublishedBy, PublishedOn
- `database-context/tables/RosterWeekPublicHolidayReview/` - NEW — key columns: RosterWeekId, PublicHolidayId, PublicHolidayDate, IsComplete, CompletedBy, CompletedAt, WageThreshold, SalaryThreshold, MondayisedFromReviewId (self-ref FK)
- `database-context/tables/ScheduleStatus/` - NEW (static entity) — values: -1 NotOpenedYet, 1 RosterOpened, 2 RosterPublished, 3 TimecardsReleased, 4 LeaveReleased, 5 PayweekClosed
- `database-context/tables/OT_LeaveBalance/` - NEW — external table with id_ prefix convention

## Entity Relationship Chain (PH Mondayized)

```
BusinessUser
  └── EmployeeWeek (BusinessUserId, WeekEndDate)
        └── PublicHolidayReview (EmployeeWeekId)
              ├── HolidayDate — the date this review is for
              ├── IsObserved — KEY: does the employee observe PH on this date?
              ├── IsEntitledBySystem / IsEntitledByOverride — entitlement flags
              └── RosterWeekPublicHolidayReview (RosterWeekPHReviewId)
                    ├── PublicHoliday (PublicHolidayId) — holiday name + IsMondayisable
                    ├── MondayisedFromReviewId → self (links Mondayized to original)
                    └── RosterWeek (RosterWeekId) — week dates + ScheduleStatusId

Note: EmployeeWeek does NOT have RosterWeekId FK — uses WeekEndDate instead
```

## Key Decisions
- **Part 1**: Pure UI logic — OnAfterFetch check on ScheduleStatusId
- **Part 2**: Bug is in RosterManagement_CS server action `GetHolidayLists`, not in Leave_UI
- **Table docs**: All 7 tables documented from entity screenshots, processed one at a time
- **CLAUDE.md updated**: Added rule to process entity screenshots one at a time

## Queries Created
- None — this story is purely OutSystems logic changes

## Next Steps
1. **Confirm**: Is the `Parent complete & Not Observed?` If node shared between both paths or separate?
2. **Apply fix**: Swap the True/False branches on the Mondayisable path (or create a new If node)
3. **Test**: Check same employee (e.g., Akanihi WINIATA-HEITIA) in both weeks — badge should show on only one date
4. **Verify**: Remove fix and confirm bug exists (badge shows on both dates)

## Quick Resume
1. Read this context file — especially the "GetHolidayLists Server Action" section
2. The bug is True/False swapped on the Mondayisable & Past path's `Parent complete & Not Observed?` check
3. Fix: swap the branches so NOT observed → skip (not append)
