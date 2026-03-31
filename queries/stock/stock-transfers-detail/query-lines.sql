-- =============================================
-- Query: Stock Transfer Detail - Line Items
-- Purpose: Returns line items for the Transfer Detail screen
-- Story: 1.3.2 - View Transfer Detail (Pending)
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2026-03-31
-- =============================================

-- Input Parameters (OutSystems):
--   @StockMovementId  BIGINT  Expand Inline = NO  The transfer to view

SELECT
    sml.Id AS LineId,
    sml.PhysicalItemId,

    -- Item info
    pi.WrinNumber AS Code,
    sml.Description,

    -- Quantities
    ISNULL(sml.QtyOfCases, 0) AS Cartons,
    ISNULL(sml.QtyOfInners, 0) AS Inners,
    ISNULL(sml.QtyOfLoose, 0) AS Units,
    sml.QtyTotal AS TotalUnits,

    -- Pricing
    sml.UnitPrice AS PricePerUnit,
    sml.NetAmount AS Cost

FROM {StockMovementLine} sml
INNER JOIN {PhysicalItem} pi ON sml.PhysicalItemId = pi.Id
WHERE sml.StockMovementId = @StockMovementId
