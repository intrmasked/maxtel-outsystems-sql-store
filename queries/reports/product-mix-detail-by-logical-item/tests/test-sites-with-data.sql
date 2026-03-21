-- =============================================
-- Test: Which sites have LogicalItemUsage data?
-- Purpose: Find sites with data so we can pick one for testing
-- =============================================

SELECT
    liu.SiteId,
    ISNULL(s.DisplayName, s.Name) AS SiteName,
    COUNT(DISTINCT liu.CalendarDate) AS DaysWithData,
    MIN(liu.CalendarDate) AS EarliestDate,
    MAX(liu.CalendarDate) AS LatestDate,
    COUNT(*) AS UsageRows,
    SUM(liu.SalesNetAmt) AS TotalSalesNet
FROM {LogicalItemUsage} liu
LEFT JOIN {Site} s ON liu.SiteId = s.Id
GROUP BY liu.SiteId, ISNULL(s.DisplayName, s.Name)
ORDER BY TotalSalesNet DESC;
