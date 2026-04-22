-- =============================================
-- Test: Get Wasteable Items With Cost — SSMS Version
-- Purpose: Verify wasteable items × shifts matrix with CostPerUnit
-- Target: SQL Server 2016+ (SSMS sandbox)
-- =============================================

DECLARE @SiteId BIGINT = 3187;

SELECT
    li.Id                AS LogicalItemId,
    li.ItemName,
    li.WrinNumber,
    dp.Id                AS DayPartsId,
    dp.Label             AS ShiftLabel,
    dp.[Order]           AS ShiftOrder,
    pi.UnitName,
    pi.UnitsInCarton,
    ISNULL(price.Value, 0) AS RawPrice,
    CASE
        WHEN pi.UnitsInCarton IS NULL OR pi.UnitsInCarton = 0 THEN 0
        ELSE ISNULL(price.Value, 0) / pi.UnitsInCarton
    END                  AS CostPerUnit,
    -- Verification columns
    COUNT(*) OVER()      AS Total_Rows

FROM {LogicalItem} li

INNER JOIN {LogicalItemSiteConfig} lisc
    ON lisc.LogicalItemId = li.Id
    AND lisc.SiteId = @SiteId
    AND lisc.IsActive = 1
    AND lisc.IsWasteable = 1

INNER JOIN {PhysicalItem} pi
    ON pi.Id = li.DefaultPhysicalItemId

INNER JOIN {DayParts} dp
    ON dp.ConceptId = li.ConceptId

OUTER APPLY (
    SELECT TOP 1 rip.Value
    FROM {BO_RawItemPrice} rip
    WHERE rip.ConceptId = pi.ConceptId
      AND rip.WRIN = pi.WrinNumber
      AND rip.Effective <= GETDATE()
    ORDER BY rip.Effective DESC
) price

ORDER BY li.ItemName, dp.[Order]
