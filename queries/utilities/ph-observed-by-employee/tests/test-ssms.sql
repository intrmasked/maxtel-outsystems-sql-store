-- =============================================
-- Test: PH Observed Date by Employee
-- Purpose: Shows which date each employee observes a PH on
--          for a given site and week. Useful for debugging
--          Mondayized PH badge display on Leave Release.
-- Target: SQL Server 2014+
-- Story: #3825
-- Created: 2026-05-26
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @BusinessUserId BIGINT = 312565;
DECLARE @WeekEndDate DATE = '2026-03-01';  -- Week containing the original PH (28 Feb)
SELECT
    p.Name                          AS EmployeeName,
    ew.BusinessUserId,
    ew.WeekEndDate,
    ph.Name                         AS HolidayName,
    ph.Date                         AS HolidayCalendarDate,
    ph.IsMondayisable,
    CASE
        WHEN ph.MondayisedFmPublicHolidayId IS NULL
          OR ph.MondayisedFmPublicHolidayId = 0
        THEN 'Original'
        ELSE 'Mondayized'
    END                             AS HolidayType,
    phr.HolidayDate                 AS ReviewDate,
    phr.IsObserved,
    phr.IsEntitledBySystem,
    phr.IsEntitledByOverride,
    rwphr.IsComplete                AS WeekReviewComplete
FROM {PublicHolidayReview} phr
INNER JOIN {EmployeeWeek} ew
    ON ew.Id = phr.EmployeeWeekId
INNER JOIN {BusinessUser} bu
    ON bu.Id = ew.BusinessUserId
INNER JOIN {Person} p
    ON p.Id = bu.PersonId
INNER JOIN {RosterWeekPublicHolidayReview} rwphr
    ON rwphr.Id = phr.RosterWeekPHReviewId
INNER JOIN {PublicHoliday} ph
    ON ph.Id = rwphr.PublicHolidayId
INNER JOIN {RosterWeek} rw
    ON rw.Id = rwphr.RosterWeekId
    AND rw.SiteId = @SiteId
WHERE ew.WeekEndDate IN (@WeekEndDate, DATEADD(DAY, 7, @WeekEndDate))
  AND ew.BusinessUserId = @BusinessUserId
ORDER BY p.Name, phr.HolidayDate;
