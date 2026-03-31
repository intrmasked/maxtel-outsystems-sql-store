-- =============================================
-- Query: Stock Transfer Detail - Header
-- Purpose: Returns transfer header, approval status panel,
--          and memo for the Transfer Detail screen
-- Story: 1.3.2 - View Transfer Detail (Pending)
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2026-03-31
-- =============================================

-- Input Parameters (OutSystems):
--   @StockMovementId  BIGINT  Expand Inline = NO  The transfer to view

SELECT
    sm.Id AS StockMovementId,

    -- Transfer info
    sm.Date AS ApprovedDate,
    sm.CreatedAt,

    -- Sites
    t.FromSiteId,
    sm.DeliverySiteId AS ToSiteId,
    fromSite.DisplayName AS FromSiteName,
    toSite.DisplayName AS ToSiteName,

    -- Status
    t.IsApproved,

    -- Approval panel - Sending side (auto-approved at creation)
    createdByUser.Name AS SenderApprovedByName,
    sm.CreatedAt AS SenderApprovedAt,

    -- Approval panel - Receiving side
    approvedByUser.Name AS ReceiverApprovedByName,
    t.ApprovedAt AS ReceiverApprovedAt,

    -- Amounts
    ISNULL(sm.NetAmount, lineTotals.TotalNetAmount) AS NetAmount,
    ISNULL(sm.TaxAmount, lineTotals.TotalNetAmount * 0.1) AS TaxAmount,
    ISNULL(sm.GrossAmount, lineTotals.TotalNetAmount * 1.1) AS GrossAmount,

    -- Memo
    t.Comment

FROM {Transfer} t
INNER JOIN {StockMovement} sm ON t.StockMovementId = sm.Id
INNER JOIN {Site} fromSite ON t.FromSiteId = fromSite.Id
INNER JOIN {Site} toSite ON sm.DeliverySiteId = toSite.Id
LEFT JOIN {User} createdByUser ON sm.CreatedBy = createdByUser.Id
LEFT JOIN {User} approvedByUser ON t.ApprovedByUserId = approvedByUser.Id

-- Line totals for pending transfers (sm amounts are null)
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
