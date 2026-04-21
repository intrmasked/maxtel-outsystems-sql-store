-- =============================================
-- Test: Check each table has data independently
-- Purpose: Identify which table is empty / causing no results
-- Target: SQL Server 2016+ (SSMS sandbox)
-- =============================================

DECLARE @SiteId BIGINT = 3187;

SELECT
    -- LogicalItems that exist
    (SELECT COUNT(*) FROM {LogicalItem}) AS Total_LogicalItems,

    -- LogicalItemSiteConfig rows for this site
    (SELECT COUNT(*) FROM {LogicalItemSiteConfig} WHERE SiteId = @SiteId) AS SiteConfig_Total,

    -- Active + Wasteable for this site
    (SELECT COUNT(*) FROM {LogicalItemSiteConfig}
     WHERE SiteId = @SiteId AND IsActive = 1 AND IsWasteable = 1) AS SiteConfig_ActiveWasteable,

    -- LogicalItems with a DefaultPhysicalItemId set
    (SELECT COUNT(*) FROM {LogicalItem} WHERE DefaultPhysicalItemId IS NOT NULL) AS Items_WithPhysicalItem,

    -- PhysicalItems total
    (SELECT COUNT(*) FROM {PhysicalItem}) AS Total_PhysicalItems,

    -- DayParts total
    (SELECT COUNT(*) FROM {DayParts}) AS Total_DayParts,

    -- BO_RawItemPrice total
    (SELECT COUNT(*) FROM {BO_RawItemPrice}) AS Total_Prices
