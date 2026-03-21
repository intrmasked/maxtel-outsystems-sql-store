-- =============================================
-- Test: Explore LogicalItem + LogicalItemUsage data across whole DB
-- Purpose: See what data exists in both tables, how many items, sites, dates
-- =============================================

SELECT
    COUNT(DISTINCT li.Id) AS TotalLogicalItems,
    COUNT(DISTINCT liu.SiteId) AS TotalSites,
    COUNT(DISTINCT liu.CalendarDate) AS TotalDates,
    COUNT(*) AS TotalUsageRows,
    MIN(liu.CalendarDate) AS EarliestDate,
    MAX(liu.CalendarDate) AS LatestDate,
    SUM(liu.SalesNetAmt) AS TotalSalesNetAmt,
    SUM(liu.SalesQty) AS TotalSalesQty,
    -- Sample: top values to confirm data shape
    MIN(li.WrinNumber) AS SampleWrinMin,
    MAX(li.WrinNumber) AS SampleWrinMax,
    MIN(li.ItemName) AS SampleNameMin,
    MAX(li.ItemName) AS SampleNameMax
FROM {LogicalItemUsage} liu
INNER JOIN {LogicalItem} li ON liu.LogicalItemId = li.Id;
