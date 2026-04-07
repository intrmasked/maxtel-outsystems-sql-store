-- =============================================
-- Query: Stock Transfers List
-- Purpose: Returns transfer list for Pending or Completed view
--          with direction indicators and context-aware status badges
-- Story: 1.3.1 - View Transfer List
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2026-03-31
-- =============================================

-- Input Parameters (OutSystems):
--   @SiteIds       VARCHAR   Expand Inline = YES  Comma-separated Site IDs the user has access to
--   @ViewType      VARCHAR   Expand Inline = NO   'P' = Pending, 'A' = Approved/Completed
--   @FilterSiteId  BIGINT    Expand Inline = NO   Optional: filter to transfers involving this specific site (0 = all)
--   @StartDate     DATE      Expand Inline = NO   Optional: filter start date (Completed view only)
--   @EndDate       DATE      Expand Inline = NO   Optional: filter end date (Completed view only)
--   @SelectedSiteId BIGINT   Expand Inline = NO   Currently selected site from sidebar
--   @CountryCode   VARCHAR   Expand Inline = NO   Tenant country code: 'AU', 'NZ', or 'Fj' (from GetTenantCountryCode())

WITH

-- [CTE 1]: InputVar — Force OutSystems to bind parameters early
InputVar AS (
    SELECT
        @ViewType AS ViewType,
        @SelectedSiteId AS SelectedSiteId,
        @FilterSiteId AS FilterSiteId,
        @StartDate AS StartDate,
        @EndDate AS EndDate,
        @CountryCode AS CountryCode,
        CASE @CountryCode
            WHEN 'AU' THEN 0.10
            WHEN 'NZ' THEN 0.15
            WHEN 'Fj' THEN 0.15
            ELSE 0.10
        END AS GSTRate
),

-- [CTE 2]: Get all transfers involving user's accessible sites
TransferData AS (
    SELECT
        sm.Id AS StockMovementId,
        t.FromSiteId,
        sm.DeliverySiteId AS ToSiteId,
        t.IsApproved,
        t.Comment,

        -- Dates
        sm.CreatedAt,
        sm.Date AS ApprovedDate,

        -- Amounts
        sm.NetAmount,
        sm.TaxAmount,
        sm.GrossAmount,

        -- Approval info
        t.ApprovedByUserId,
        t.ApprovedAt,

        -- Created by
        sm.CreatedBy

    FROM {Transfer} t
    INNER JOIN {StockMovement} sm ON t.StockMovementId = sm.Id
    WHERE sm.MovementTypeId = 2
      -- Filter by view type
      AND (
          ((SELECT ViewType FROM InputVar) = 'P' AND t.IsApproved = 0)
          OR
          ((SELECT ViewType FROM InputVar) = 'A' AND t.IsApproved = 1)
      )
      -- User must have access to at least one side of the transfer
      AND (
          t.FromSiteId IN (@SiteIds)
          OR sm.DeliverySiteId IN (@SiteIds)
      )
      -- Sidebar site filter: selected site must be on either side (0 = all sites, skip filter)
      AND (
          (SELECT SelectedSiteId FROM InputVar) = 0
          OR t.FromSiteId = (SELECT SelectedSiteId FROM InputVar)
          OR sm.DeliverySiteId = (SELECT SelectedSiteId FROM InputVar)
      )
      -- Optional: store dropdown filter — narrows to transfers between sidebar site and this specific site
      AND (
          (SELECT FilterSiteId FROM InputVar) = 0
          OR t.FromSiteId = (SELECT FilterSiteId FROM InputVar)
          OR sm.DeliverySiteId = (SELECT FilterSiteId FROM InputVar)
      )
      -- Optional: date range filter (Completed view only)
      AND (
          (SELECT ViewType FROM InputVar) = 'P'
          OR (
              ((SELECT StartDate FROM InputVar) IS NULL OR sm.Date >= (SELECT StartDate FROM InputVar))
              AND
              ((SELECT EndDate FROM InputVar) IS NULL OR sm.Date <= (SELECT EndDate FROM InputVar))
          )
      )
),

-- [CTE 3]: Line item aggregation
LineSummary AS (
    SELECT
        sml.StockMovementId,
        COUNT(*) AS LineCount,
        SUM(sml.NetAmount) AS LinesNetAmount,
        SUM(sml.NetAmount) * (SELECT GSTRate FROM InputVar) AS LinesGST,
        SUM(sml.NetAmount) * (1 + (SELECT GSTRate FROM InputVar)) AS LinesGrossAmount
    FROM {StockMovementLine} sml
    INNER JOIN TransferData td ON sml.StockMovementId = td.StockMovementId
    GROUP BY sml.StockMovementId
)

-- [FINAL]: Build output
SELECT
    td.StockMovementId,

    -- Invoice number: SiteId-XXXXXX (6 digit zero-padded StockMovementId)
    CAST(td.FromSiteId AS VARCHAR) + '-' + REPLICATE('0', 6 - LEN(CAST(td.StockMovementId AS VARCHAR))) + CAST(td.StockMovementId AS VARCHAR) AS InvoiceNumber,

    -- Direction relative to the first accessible site in the user's list
    -- OutSystems will determine direction based on viewing site context
    td.FromSiteId,
    td.ToSiteId,

    -- Site names
    fromSite.Name AS FromSiteName,
    toSite.Name AS ToSiteName,

    -- Dates
    td.CreatedAt,
    td.ApprovedDate,

    -- Line summary
    ISNULL(ls.LineCount, 0) AS LineCount,

    -- Amounts: use line-calculated amounts for pending (sm amounts are null), sm amounts for completed
    CASE
        WHEN td.IsApproved = 1 THEN ISNULL(td.NetAmount, 0)
        ELSE ISNULL(ls.LinesNetAmount, 0)
    END AS ExGST,

    CASE
        WHEN td.IsApproved = 1 THEN ISNULL(td.TaxAmount, 0)
        ELSE ISNULL(ls.LinesGST, 0)
    END AS GST,

    CASE
        WHEN td.IsApproved = 1 THEN ISNULL(td.GrossAmount, 0)
        ELSE ISNULL(ls.LinesGrossAmount, 0)
    END AS Total,

    -- Status
    td.IsApproved,

    -- Approval info (Completed view)
    createdByUser.Name AS CreatedByName,
    approvedByUser.Name AS ApprovedByName,
    td.ApprovedAt,

    -- Memo
    td.Comment

FROM TransferData td

-- Site names
INNER JOIN {Site} fromSite ON td.FromSiteId = fromSite.Id
INNER JOIN {Site} toSite ON td.ToSiteId = toSite.Id

-- Line summary
LEFT JOIN LineSummary ls ON ls.StockMovementId = td.StockMovementId

-- User names
LEFT JOIN {User} createdByUser ON td.CreatedBy = createdByUser.Id
LEFT JOIN {User} approvedByUser ON td.ApprovedByUserId = approvedByUser.Id
