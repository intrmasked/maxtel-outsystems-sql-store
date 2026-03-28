-- =============================================
-- Test: Find sites and dates that have StockPeriodBalance data
-- Purpose: Discover which sites/dates have data so you can test the main query
-- =============================================

SELECT
    SP.SiteId,
    MIN(SP.Date) AS EarliestDate,
    MAX(SP.Date) AS LatestDate,
    COUNT(DISTINCT SP.Date) AS TotalDays,
    COUNT(DISTINCT SB.LogicalItemId) AS UniqueItems,
    COUNT(*) AS TotalRows
FROM {StockPeriodBalance} SB
JOIN {StockPeriod} SP ON SB.StockPeriodId = SP.Id
GROUP BY SP.SiteId
ORDER BY SP.SiteId
