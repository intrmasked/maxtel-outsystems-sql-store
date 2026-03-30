-- =============================================
-- Query: GetRawStockItemDetail
-- Purpose: Item Detail card for Raw Stock detail screen.
--          Returns a single row with item metadata.
--          Separate from main grid query so OutSystems
--          can call it independently (like TotalVariance on list screen).
--
-- Target: SQL Server 2016+ / OutSystems Advanced SQL
-- Created: 2026-03-30
-- =============================================

WITH

-- [CTE 0]: InputVar — force OutSystems parameter binding (Lazy Parser fix)
InputVar AS (
    SELECT @LogicalItemId AS LogicalItemId
)

SELECT
    LI.ItemName,
    LI.ItemType,
    LI.WrinNumber,
    PI.UnitName,
    CSI.DefaultCountPeriodId
FROM {LogicalItem} LI
JOIN {PhysicalItem} PI            ON LI.DefaultPhysicalItemId = PI.Id
LEFT JOIN {CentralStockItem} CSI  ON LI.ConceptId = CSI.ConceptId
                                  AND LI.WrinNumber = CSI.WrinNumberClean
WHERE LI.Id = (SELECT LogicalItemId FROM InputVar)
