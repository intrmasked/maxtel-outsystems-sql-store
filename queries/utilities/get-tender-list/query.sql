-- =============================================
-- Query: operating-periods/get-tender-list.sql
-- Version: v1.0.0
-- Purpose: Retrieves the full list of report rows (Dynamic Tenders + Fixed Metrics) based on filters.
-- =============================================

/* 
    OUTSYSTEMS PARAMETERS:
    - SiteIds (Text)       → ⚠️ Expand Inline = YES ⚠️
    - StartDate (Date)
    - EndDate (Date)
    - SelectedView (Text)  → 'D' (Dollars), 'G' (Guests), 'A' (Average)
*/

-- A. Expected Total Takings (Conditional)
SELECT NULL AS TenderTypeId, 'Expected Total Takings' AS Name, 10 AS SortOrder
WHERE @SelectedView = 'D'

UNION ALL

-- B. Dynamic Tenders (Filtered by Range/Sites)
SELECT DISTINCT tt.Id, tt.Name, 50 + tt.[Order] AS SortOrder
FROM {TenderType} tt
INNER JOIN {SWCPeriodTender} spt ON tt.Id = spt.TenderTypeId
INNER JOIN {SWCPeriod} p ON spt.OperatingPeriodId = p.Id
WHERE p.SiteId IN (@SiteIds)
  AND p.BusDate BETWEEN @StartDate AND @EndDate

UNION ALL

-- C. Actual Total Takings (Always)
SELECT NULL, 'Actual Total Takings', 90

UNION ALL

-- D. Variance (Conditional)
SELECT NULL, 'Variance', 100
WHERE @SelectedView = 'D'

UNION ALL

-- E. Information (Always)
SELECT NULL, 'Information', 110

ORDER BY SortOrder, Name;
