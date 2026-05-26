# Table: ScheduleStatus (Static Entity)

**OutSystems Entity**: ScheduleStatus
**Module**: RosterManagement_CS
**Type**: Static Entity (lookup/enum)
**Purpose**: Defines the lifecycle statuses for a RosterWeek.
**Last Updated**: 2026-05-24

---

## Overview

ScheduleStatus is a **static entity** (enum) that defines the lifecycle states of a roster week. Referenced by `RosterWeek.ScheduleStatusId`.

---

## Values

| Id | Label | Description |
|----|-------|-------------|
| -1 | NotOpenedYet | Roster week has not been opened yet |
| 1 | RosterOpened | Roster is open and being edited |
| 2 | RosterPublished | Roster has been published to employees |
| 3 | TimecardsReleased | Timecards have been released |
| 4 | LeaveReleased | Leave has been released |
| 5 | PayweekClosed | Pay week is finalized and closed |

---

## Story 3825 Relevance

**Part 1 of story**: When entering Leave Release week, if the roster week's `ScheduleStatusId` is **5 (PayweekClosed)**, the Leave Release filter should default to "All" instead of "Pending".

> **Note**: Confirm whether "closed week" means specifically `PayweekClosed (5)` or any status >= a certain threshold (e.g., `LeaveReleased (4)` or `PayweekClosed (5)`).

---

## Usage in Queries

```sql
-- Check if a roster week is closed
SELECT rw.Id
FROM {RosterWeek} rw
WHERE rw.SiteId = @SiteId
  AND rw.ScheduleStatusId = 5  -- PayweekClosed
```

---

## Related Tables

- [RosterWeek](../RosterWeek/README.md) - References this static entity via ScheduleStatusId

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-05-24 | Claude + Abdul | Initial documentation for story 3825 |
| 2026-05-24 | Claude + Abdul | Updated with confirmed values: -1 NotOpenedYet, 1-5 lifecycle states |
