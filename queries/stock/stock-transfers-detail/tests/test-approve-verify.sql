-- =============================================
-- Test: Verify Transfer Approval
-- Purpose: Check all records updated correctly after approve
-- Usage: Set @StockMovementId to the approved transfer
-- =============================================

DECLARE @StockMovementId BIGINT = 40;

SELECT
    -- StockMovement
    sm.Id AS StockMovementId,
    sm.Date AS ApprovedDate,
    sm.NetAmount AS SM_NetAmount,
    sm.TaxAmount AS SM_TaxAmount,
    sm.GrossAmount AS SM_GrossAmount,

    -- Transfer
    t.IsApproved,
    t.ApprovedByUserId,
    t.ApprovedAt,
    t.FromSiteId,
    sm.DeliverySiteId AS ToSiteId,

    -- Line items summary
    lineStats.LineCount,
    lineStats.LinesTotalNet,

    -- Sender StockPeriodBalance
    senderBal.SenderTransferQty,
    senderBal.SenderItemCount,

    -- Receiver StockPeriodBalance
    receiverBal.ReceiverTransferQty,
    receiverBal.ReceiverItemCount

FROM {StockMovement} sm
INNER JOIN {Transfer} t ON t.StockMovementId = sm.Id

-- Line items summary
CROSS APPLY (
    SELECT
        COUNT(*) AS LineCount,
        SUM(sml.NetAmount) AS LinesTotalNet
    FROM {StockMovementLine} sml
    WHERE sml.StockMovementId = sm.Id
) lineStats

-- Sender balance check (sum of TransferQty for items in this transfer on approved date)
CROSS APPLY (
    SELECT
        SUM(spb.TransferQty) AS SenderTransferQty,
        COUNT(*) AS SenderItemCount
    FROM {StockPeriodBalance} spb
    INNER JOIN {StockPeriod} sp ON spb.StockPeriodId = sp.Id
    INNER JOIN {StockMovementLine} sml ON sml.StockMovementId = sm.Id
    INNER JOIN {LogicalItem} li ON li.Id = spb.LogicalItemId
    INNER JOIN {PhysicalItem} pi ON pi.Id = li.DefaultPhysicalItemId
    WHERE sp.SiteId = t.FromSiteId
      AND sp.Date = sm.Date
      AND pi.Id = sml.PhysicalItemId
) senderBal

-- Receiver balance check
CROSS APPLY (
    SELECT
        SUM(spb.TransferQty) AS ReceiverTransferQty,
        COUNT(*) AS ReceiverItemCount
    FROM {StockPeriodBalance} spb
    INNER JOIN {StockPeriod} sp ON spb.StockPeriodId = sp.Id
    INNER JOIN {StockMovementLine} sml ON sml.StockMovementId = sm.Id
    INNER JOIN {LogicalItem} li ON li.Id = spb.LogicalItemId
    INNER JOIN {PhysicalItem} pi ON pi.Id = li.DefaultPhysicalItemId
    WHERE sp.SiteId = sm.DeliverySiteId
      AND sp.Date = sm.Date
      AND pi.Id = sml.PhysicalItemId
) receiverBal

WHERE sm.Id = @StockMovementId
