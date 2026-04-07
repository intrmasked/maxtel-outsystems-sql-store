-- =============================================
-- Test: Stock Transfer Detail - Header (SSMS Version)
-- Purpose: Test header query in sandbox
-- =============================================

DECLARE @StockMovementId BIGINT = 40;
DECLARE @CountryCode VARCHAR(2) = 'NZ';

WITH InputVar AS (
    SELECT
        @CountryCode AS CountryCode,
        CASE @CountryCode
            WHEN 'AU' THEN 0.10
            WHEN 'NZ' THEN 0.15
            WHEN 'Fj' THEN 0.15
            ELSE 0.10
        END AS GSTRate
)

SELECT
    sm.Id AS StockMovementId,

    -- Invoice number: SiteId-XXXXXX
    CAST(t.FromSiteId AS VARCHAR) + '-' + REPLICATE('0', 6 - LEN(CAST(sm.Id AS VARCHAR))) + CAST(sm.Id AS VARCHAR) AS InvoiceNumber,

    -- Transfer info
    sm.Date AS ApprovedDate,
    sm.CreatedAt,

    -- Sites
    t.FromSiteId,
    sm.DeliverySiteId AS ToSiteId,
    fromSite.Name AS FromSiteName,
    toSite.Name AS ToSiteName,

    -- Status
    t.IsApproved,

    -- Approval panel - Sending side (auto-approved at creation)
    createdByUser.Name AS SenderApprovedByName,
    sm.CreatedAt AS SenderApprovedAt,

    -- Approval panel - Receiving side
    approvedByUser.Name AS ReceiverApprovedByName,
    t.ApprovedAt AS ReceiverApprovedAt,

    -- Amounts (fall back to line totals when sm amounts are 0/null)
    CASE WHEN ISNULL(sm.NetAmount, 0) = 0 THEN ISNULL(lineTotals.TotalNetAmount, 0) ELSE sm.NetAmount END AS NetAmount,
    CASE WHEN ISNULL(sm.TaxAmount, 0) = 0 THEN ISNULL(lineTotals.TotalNetAmount, 0) * (SELECT GSTRate FROM InputVar) ELSE sm.TaxAmount END AS TaxAmount,
    CASE WHEN ISNULL(sm.GrossAmount, 0) = 0 THEN ISNULL(lineTotals.TotalNetAmount, 0) * (1 + (SELECT GSTRate FROM InputVar)) ELSE sm.GrossAmount END AS GrossAmount,

    -- Memo
    t.Comment

FROM {Transfer} t
INNER JOIN {StockMovement} sm ON t.StockMovementId = sm.Id
INNER JOIN {Site} fromSite ON t.FromSiteId = fromSite.Id
INNER JOIN {Site} toSite ON sm.DeliverySiteId = toSite.Id
LEFT JOIN {User} createdByUser ON sm.CreatedBy = createdByUser.Id
LEFT JOIN {User} approvedByUser ON t.ApprovedByUserId = approvedByUser.Id

-- Line totals for pending transfers (sm amounts are 0/null)
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
