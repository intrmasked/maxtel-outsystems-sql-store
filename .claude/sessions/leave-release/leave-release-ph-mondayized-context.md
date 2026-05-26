# Session: Leave Release PH Mondayized Fix - 2026-05-24

## Original Story/Requirements

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_workitems/edit/3825
**Branch:** `story/3825-leave-release-ph-mondayized`

### Part 1: Leave Release Filter Default ✅ WORKING
When entering Leave Release week, the filter defaults to "Pending" in all cases. It should check the roster week's ScheduleStatus — if the week is **Closed** (PayweekClosed, Id=5) or **LeaveReleased** (Id=4), default to "All" instead of "Pending". This is in **Leave_UI**.

**Fix applied**: OnAfterFetch of `GetRosterWeeksBySiteId` → If `ScheduleStatusId = PayweekClosed OR LeaveReleased` → set ViewType = "All" → call `ButtonGroup2OnChange`. Tested and working.

**Potential issue**: If `ButtonGroup2OnChange` refreshes everything (including `GetRosterWeeksBySiteId`), it could cause an infinite loop. If so, add an `IsInitialLoad` boolean guard. During testing it didn't loop, but watch for it.

### Part 2: PH Mondayized Badge Fix ✅ VERIFIED

**Problem**: PH badge shows on both the original and Mondayized date for all employees. Should only show on the day the employee has `IsObserved = 1`.

**Root cause identified**: The bug is in **`GetHolidayLists`** server action in **RosterManagement_CS** (not in the Leave_UI Data Action).

## GetHolidayLists Server Action — Full Flow (Corrected 2026-05-26)

### Inputs
- `BusinessUserId`, `WeekEndDate`, `SiteId` (and likely others)

### Data Sources
- **`GetPublicHolidaysBySiteId`** Aggregate — fetches from PublicHoliday + RosterWeekPublicHolidayReview

### Flow (as described by Abdul 2026-05-26)

```
For each PH in GetPublicHolidaysBySiteId.List:
│
├── Mondayised? (MondayisedFmPublicHolidayId <> NullIdentifier())
│   │
│   ├── TRUE — This IS a Mondayized record (e.g., Mon 2 Mar)
│   │   └── WeekEndDate < DateTimeToDate(DateTime_ConvertUTCtoLocal(CurrDateTime()))
│   │       ├── TRUE → GetParentPublicHolidayReviewById
│   │       │   └── Parent complete & Not Observed?
│   │       │       ├── TRUE → No Op (skip) ← 🐛 BUG — should ListAppend
│   │       │       └── FALSE → ListAppend  ← 🐛 BUG — should skip
│   │       └── FALSE → No Op (far-right) → No Op (bottom-left) → loop
│   │
│   └── FALSE — This is NOT a Mondayized record (original or normal PH)
│       │
│       ├── Mondayisable & Past?
│       │   ├── TRUE → GetEmployeeWeeksByBusinessUserId
│       │   │   └── Diamond check: IsObserved?
│       │   │       ├── TRUE → ListAppend ✓ CORRECT (observed on original → show)
│       │   │       └── FALSE → No Op ✓ CORRECT (not observed → skip)
│       │   │
│       │   └── FALSE → ListAppend (normal non-Mondayisable PH → always show)
│       │
```

### The Bug — Branch A True/False Swapped

Branch A (Mondayised = True) has `Parent complete & Not Observed?`:
- **True** (not observed on parent Sat) → **No Op** — ❌ WRONG. Should ListAppend (employee observes Mon, show Mon badge)
- **False** (observed on parent Sat) → **ListAppend** — ❌ WRONG. Should No Op (employee observes Sat, skip Mon)

Branch B (Mondayisable & Past = True) uses `IsObserved` directly:
- **True** → ListAppend — ✅ CORRECT
- **False** → No Op — ✅ CORRECT

### Fix Applied & Verified (2026-05-26)
**Swapped True/False connectors** on the `Parent complete & Not Observed?` If node in Branch A:
- **True** (not observed on parent) → **ListAppend** (show Mondayized badge)
- **False** (observed on parent) → **No Op** (skip Mondayized date)

Branch B left untouched — it was already correct.

### Verification (2026-05-26)
Tested with two employees at site 3187:
- **Ajay LAWRENCE-WILLIAMS-POMANA** (267904): `IsObserved=False` on 28 Feb, `IsObserved=True` on 2 Mar → badge shows on 2 Mar only ✅
- **Akanihi WINIATA-HEITIA** (312565): `IsObserved=True` on 28 Feb, `IsObserved=False` on 2 Mar → badge shows on 28 Feb only ✅
- Reverted swap to confirm bug returned (badge on both dates) → re-applied swap → fix confirmed ✅

## Status
- [ ] Complete / [ ] In Progress / [x] Needs Review

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
- **Part 1**: Pure UI logic — OnAfterFetch check on ScheduleStatusId. Default to "All" when PayweekClosed OR LeaveReleased.
- **Part 2**: Bug is in RosterManagement_CS server action `GetHolidayLists`, not in Leave_UI
- **Branch A fix**: Swapped True/False on `Parent complete & Not Observed?` — separate node from Branch B
- **Branch B**: Uses `IsObserved` directly, was already correct, left untouched
- **Table docs**: All 7 tables documented from entity screenshots, processed one at a time
- **CLAUDE.md updated**: Added rule to process entity screenshots one at a time

## Queries Created
- `queries/utilities/ph-observed-by-employee/tests/test-ssms.sql` — debug query showing which date each employee observes a PH on for a given site/week

## Next Steps
1. **Abdul to review** and confirm ready for QA / production
2. **Broader regression testing** — check other Mondayized PHs across different sites

## Quick Resume
1. Read this context file
2. Both parts fixed and verified:
   - Part 1: Filter defaults to "All" when PayweekClosed or LeaveReleased ✅
   - Part 2: Branch A True/False swapped on `Parent complete & Not Observed?` ✅
3. Debug query: `queries/utilities/ph-observed-by-employee/tests/test-ssms.sql`
