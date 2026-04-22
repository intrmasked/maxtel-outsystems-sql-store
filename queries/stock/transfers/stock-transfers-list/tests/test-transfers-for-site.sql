-- =============================================
-- Test: All Transfers for a Specific Site
-- Purpose: Quick diagnostic — show every transfer (pending + completed)
--          where the given site is sender or receiver
-- Target: SSMS / SQL Server 2014+
-- Created: 2026-04-12
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 3187;  -- Change to test different sites

SELECT
    sm.Id AS StockMovementId,

    -- Invoice number: SiteId-XXXXXX
    CAST(t.FromSiteId AS VARCHAR) + '-'
        + REPLICATE('0', 6 - LEN(CAST(sm.Id AS VARCHAR)))
        + CAST(sm.Id AS VARCHAR) AS InvoiceNumber,

    -- Sides
    t.FromSiteId,
    fromSite.Name AS FromSiteName,
    sm.DeliverySiteId AS ToSiteId,
    toSite.Name AS ToSiteName,

    -- Direction relative to @SiteId
    CASE
        WHEN t.FromSiteId = @SiteId THEN 'OUT'
        WHEN sm.DeliverySiteId = @SiteId THEN 'IN'
        ELSE 'N/A'
    END AS Direction,

    -- Status
    CASE t.IsApproved
        WHEN 0 THEN 'Pending'
        WHEN 1 THEN 'Approved'
    END AS Status,

    -- Dates & amounts
    sm.CreatedAt,
    sm.Date AS ApprovedDate,
    ISNULL(sm.NetAmount, 0) AS NetAmount,
    ISNULL(sm.GrossAmount, 0) AS GrossAmount,

    -- People
    createdByUser.Name AS CreatedByName,
    approvedByUser.Name AS ApprovedByName,

    -- Memo
    t.Comment,

    -- Verification stats (single SELECT — sandbox-safe)
    COUNT(*) OVER() AS Total_Transfers,
    SUM(CASE WHEN t.IsApproved = 0 THEN 1 ELSE 0 END) OVER() AS Total_Pending,
    SUM(CASE WHEN t.IsApproved = 1 THEN 1 ELSE 0 END) OVER() AS Total_Approved,
    SUM(CASE WHEN t.FromSiteId = @SiteId THEN 1 ELSE 0 END) OVER() AS Total_Outgoing,
    SUM(CASE WHEN sm.DeliverySiteId = @SiteId THEN 1 ELSE 0 END) OVER() AS Total_Incoming

FROM {Transfer} t
INNER JOIN {StockMovement} sm ON t.StockMovementId = sm.Id
INNER JOIN {Site} fromSite ON t.FromSiteId = fromSite.Id
INNER JOIN {Site} toSite ON sm.DeliverySiteId = toSite.Id
LEFT JOIN {User} createdByUser ON sm.CreatedBy = createdByUser.Id
LEFT JOIN {User} approvedByUser ON t.ApprovedByUserId = approvedByUser.Id
WHERE sm.MovementTypeId = 2                                -- Transfer movements only
  AND (t.FromSiteId = @SiteId OR sm.DeliverySiteId = @SiteId)
ORDER BY sm.CreatedAt DESC;
