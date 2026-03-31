-- =============================================
-- Test: Stock Transfer Detail (SSMS Version)
-- Purpose: Test both header and lines queries together
-- =============================================

DECLARE @StockMovementId BIGINT = 1;  -- Change to a real ID

-- === HEADER ===
SELECT
    sm.Id AS StockMovementId,
    sm.Date AS ApprovedDate,
    sm.CreatedAt,
    t.FromSiteId,
    sm.DeliverySiteId AS ToSiteId,
    fromSite.DisplayName AS FromSiteName,
    toSite.DisplayName AS ToSiteName,
    t.IsApproved,
    createdByUser.Name AS SenderApprovedByName,
    sm.CreatedAt AS SenderApprovedAt,
    approvedByUser.Name AS ReceiverApprovedByName,
    t.ApprovedAt AS ReceiverApprovedAt,
    ISNULL(sm.NetAmount, lineTotals.TotalNetAmount) AS NetAmount,
    ISNULL(sm.TaxAmount, lineTotals.TotalNetAmount * 0.1) AS TaxAmount,
    ISNULL(sm.GrossAmount, lineTotals.TotalNetAmount * 1.1) AS GrossAmount,
    t.Comment

FROM {Transfer} t
INNER JOIN {StockMovement} sm ON t.StockMovementId = sm.Id
INNER JOIN {Site} fromSite ON t.FromSiteId = fromSite.Id
INNER JOIN {Site} toSite ON sm.DeliverySiteId = toSite.Id
LEFT JOIN {User} createdByUser ON sm.CreatedBy = createdByUser.Id
LEFT JOIN {User} approvedByUser ON t.ApprovedByUserId = approvedByUser.Id
LEFT JOIN (
    SELECT
        sml.StockMovementId,
        SUM(sml.NetAmount) AS TotalNetAmount
    FROM {StockMovementLine} sml
    WHERE sml.StockMovementId = @StockMovementId
    GROUP BY sml.StockMovementId
) lineTotals ON lineTotals.StockMovementId = sm.Id

WHERE sm.Id = @StockMovementId
  AND sm.MovementTypeId = 2
