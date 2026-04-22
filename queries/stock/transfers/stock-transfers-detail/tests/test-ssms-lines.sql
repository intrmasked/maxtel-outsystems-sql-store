-- =============================================
-- Test: Stock Transfer Detail - Line Items (SSMS Version)
-- Purpose: Test lines query with total row in sandbox
-- =============================================

DECLARE @StockMovementId BIGINT = 40;

-- Line items
SELECT
    sml.Id AS LineId,
    sml.PhysicalItemId,
    pi.WrinNumber AS Code,
    sml.Description,
    ISNULL(sml.QtyOfCases, 0) AS Cartons,
    ISNULL(sml.QtyOfInners, 0) AS Inners,
    ISNULL(sml.QtyOfLoose, 0) AS Units,
    sml.QtyTotal AS TotalUnits,
    sml.UnitPrice AS PricePerUnit,
    sml.NetAmount AS Cost,
    0 AS IsTotal

FROM {StockMovementLine} sml
INNER JOIN {PhysicalItem} pi ON sml.PhysicalItemId = pi.Id
WHERE sml.StockMovementId = @StockMovementId

UNION ALL

-- Total row
SELECT
    0 AS LineId,
    0 AS PhysicalItemId,
    '' AS Code,
    '' AS Description,
    0 AS Cartons,
    0 AS Inners,
    0 AS Units,
    0 AS TotalUnits,
    0 AS PricePerUnit,
    SUM(sml.NetAmount) AS Cost,
    1 AS IsTotal

FROM {StockMovementLine} sml
WHERE sml.StockMovementId = @StockMovementId
