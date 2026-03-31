-- =============================================
-- Test: GetRawStockItemDetail — SSMS sandbox version
-- Purpose: Test Item Detail card query for a single LogicalItem
-- Target: SQL Server 2016+ (SSMS)
-- Created: 2026-03-30
-- Updated: 2026-03-30 — Resolve ItemType codes + CountPeriod label
-- =============================================

DECLARE @LogicalItemId BIGINT = 8684;  -- APPLE SLICES

SELECT
    LI.ItemName,
    CASE LI.ItemType
        WHEN 'F' THEN 'Food'
        WHEN 'P' THEN 'Paper'
        WHEN 'S' THEN 'Supplies'
        WHEN 'H' THEN 'Happy Meal'
        WHEN 'N' THEN 'No Recipe'
        ELSE LI.ItemType
    END AS ItemType,
    LI.WrinNumber,
    PI.UnitName,
    ISNULL(CP.Label, '—') AS CountFrequency
FROM {LogicalItem} LI
JOIN {PhysicalItem} PI            ON LI.DefaultPhysicalItemId = PI.Id
LEFT JOIN {CentralStockItem} CSI  ON PI.ConceptId = CSI.ConceptId
                                  AND PI.WrinNumber = CSI.WrinNumberClean
LEFT JOIN {CountPeriod} CP        ON CSI.DefaultCountPeriodId = CP.Id
WHERE LI.Id = @LogicalItemId
