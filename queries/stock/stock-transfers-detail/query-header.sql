-- =============================================
-- Query: Stock Transfer Detail - Header
-- Purpose: Returns transfer header, approval status panel,
--          and memo for the Transfer Detail screen
-- Story: 1.3.2 - View Transfer Detail (Pending)
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2026-03-31
-- =============================================

-- Input Parameters (OutSystems):
--   @StockMovementId  BIGINT    Expand Inline = NO  The transfer to view
--   @CountryCode      VARCHAR   Expand Inline = NO  Tenant country code: 'AU', 'NZ', or 'Fj' (from GetTenantCountryCode())

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

    -- Invoice number: SiteId-XXXXXX (6 digit zero-padded StockMovementId)
    CAST(t.FromSiteId AS VARCHAR) + '-' + REPLICATE('0', 6 - LEN(CAST(sm.Id AS VARCHAR))) + CAST(sm.Id AS VARCHAR) AS InvoiceNumber,

    -- Transfer info
    sm.Date AS ApprovedDate,
    sm.CreatedAt,

    -- Sites (NULL for cross-tenant sites — OutSystems resolves via access_mcw)
    t.FromSiteId,
    sm.DeliverySiteId AS ToSiteId,
    fromSite.Name AS FromSiteName,
    toSite.Name AS ToSiteName,

    -- Status
    t.IsApproved,

    -- Approval panel - Sending side (auto-approved at creation)
    -- Uses denormalized snapshot — no {User} join needed
    sm.CreatedByUserName AS SenderApprovedByName,
    sm.CreatedAt AS SenderApprovedAt,

    -- Approval panel - Receiving side
    -- Uses denormalized snapshot — no {User} join needed
    t.ApprovedByUserName AS ReceiverApprovedByName,
    t.ApprovedAt AS ReceiverApprovedAt,

    -- Amounts
    CASE WHEN ISNULL(sm.NetAmount, 0) = 0 THEN ISNULL(lineTotals.TotalNetAmount, 0) ELSE sm.NetAmount END AS NetAmount,
    CASE WHEN ISNULL(sm.TaxAmount, 0) = 0 THEN ISNULL(lineTotals.TotalNetAmount, 0) * (SELECT GSTRate FROM InputVar) ELSE sm.TaxAmount END AS TaxAmount,
    CASE WHEN ISNULL(sm.GrossAmount, 0) = 0 THEN ISNULL(lineTotals.TotalNetAmount, 0) * (1 + (SELECT GSTRate FROM InputVar)) ELSE sm.GrossAmount END AS GrossAmount,

    -- Memo
    t.Comment

FROM {Transfer} t
INNER JOIN {StockMovement} sm ON t.StockMovementId = sm.Id

-- Site names (LEFT JOIN — cross-tenant sites return NULL, resolved by OutSystems)
LEFT JOIN {Site} fromSite ON t.FromSiteId = fromSite.Id
LEFT JOIN {Site} toSite ON sm.DeliverySiteId = toSite.Id

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
