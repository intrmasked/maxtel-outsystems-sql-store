-- =============================================
-- Query: Get Wasteable Items With Cost
-- Purpose: Returns one row per (LogicalItem × DayPart) for a given site,
--          with CostPerUnit resolved from the most recent BO_RawItemPrice.
--          Used by InitRawWasteCount Server Action to bulk-create
--          RawWasteCount rows when a user first opens a date.
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2026-04-21
-- =============================================

SELECT
    li.Id                AS LogicalItemId,
    dp.Id                AS DayPartsId,
    CASE
        WHEN pi.UnitsInCarton IS NULL OR pi.UnitsInCarton = 0 THEN 0
        ELSE ISNULL(price.Value, 0) / pi.UnitsInCarton
    END                  AS CostPerUnit

FROM {LogicalItem} li

-- Only active + wasteable items for this site
INNER JOIN {LogicalItemSiteConfig} lisc
    ON lisc.LogicalItemId = li.Id
    AND lisc.SiteId = @SiteId
    AND lisc.IsActive = 1
    AND lisc.IsWasteable = 1

-- Resolve default physical item (for UnitsInCarton + price lookup)
INNER JOIN {PhysicalItem} pi
    ON pi.Id = li.DefaultPhysicalItemId

-- One row per shift for the item's concept
INNER JOIN {DayParts} dp
    ON dp.ConceptId = li.ConceptId

-- Most recent price for this physical item
OUTER APPLY (
    SELECT TOP 1 rip.Value
    FROM {BO_RawItemPrice} rip
    WHERE rip.ConceptId = pi.ConceptId
      AND rip.WRIN = pi.WrinNumber
      AND rip.Effective <= GETDATE()
    ORDER BY rip.Effective DESC
) price
