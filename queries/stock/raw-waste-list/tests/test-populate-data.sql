-- =============================================
-- Test: Populate RawWasteCount with sample data
-- Purpose: Creates test waste entries so we can
--          verify the raw-waste-list query output
-- Run this FIRST, then run test-ssms.sql
-- =============================================

-- Step 1: Check what we have to work with
-- Shows StockPeriods, DayParts, and LogicalItems available

SELECT
    '--- StockPeriods ---' AS Section,
    sp.Id AS StockPeriodId,
    sp.SiteId,
    sp.Date,
    CAST(NULL AS BIGINT) AS DayPartsId,
    CAST(NULL AS INT) AS DayPartOrder,
    CAST(NULL AS VARCHAR(50)) AS DayPartLabel,
    CAST(NULL AS BIGINT) AS LogicalItemId,
    CAST(NULL AS VARCHAR(100)) AS ItemName,
    CAST(NULL AS INT) AS ExistingRawWasteRows
FROM {StockPeriod} sp
WHERE sp.SiteId = 3187
  AND sp.Date BETWEEN '2026-04-15' AND '2026-04-22'

UNION ALL

SELECT
    '--- DayParts ---',
    CAST(NULL AS BIGINT),
    CAST(NULL AS BIGINT),
    CAST(NULL AS DATE),
    dp.Id,
    dp.[Order],
    dp.Label,
    CAST(NULL AS BIGINT),
    CAST(NULL AS VARCHAR(100)),
    CAST(NULL AS INT)
FROM {DayParts} dp

UNION ALL

SELECT TOP 5
    '--- LogicalItems (wasteable) ---',
    CAST(NULL AS BIGINT),
    CAST(NULL AS BIGINT),
    CAST(NULL AS DATE),
    CAST(NULL AS BIGINT),
    CAST(NULL AS INT),
    CAST(NULL AS VARCHAR(50)),
    li.Id,
    li.ItemName,
    CAST(NULL AS INT)
FROM {LogicalItem} li
INNER JOIN {LogicalItemSiteConfig} lisc ON lisc.LogicalItemId = li.Id
WHERE lisc.SiteId = 3187
  AND lisc.IsActive = 1
  AND lisc.IsWasteable = 1
