-- =============================================
-- Query: GetRawStockItemDetail
-- Purpose: Item Detail card for Raw Stock detail screen.
--          Returns a single row with item metadata.
--          Separate from main grid query so OutSystems
--          can call it independently (like TotalVariance on list screen).
--
-- Target: SQL Server 2016+ / OutSystems Advanced SQL
-- Created: 2026-03-30
-- Updated: 2026-03-30 — Resolve ItemType codes + CountPeriod label
-- =============================================

WITH

-- [CTE 0]: InputVar — force OutSystems parameter binding (Lazy Parser fix)
InputVar AS (
    SELECT @LogicalItemId AS LogicalItemId
)

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
WHERE LI.Id = (SELECT LogicalItemId FROM InputVar)
