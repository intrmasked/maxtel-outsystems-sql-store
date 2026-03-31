-- =============================================
-- Test: Stock Transfers List (SSMS Version)
-- Purpose: Test the transfers list query in SSMS sandbox
-- Uses DECLARE + STRING_SPLIT for @SiteIds
-- =============================================

DECLARE @SiteIds VARCHAR(200) = '3187,3188,3189';
DECLARE @ViewType VARCHAR(1) = 'P';       -- 'P' = Pending, 'C' = Completed
DECLARE @FilterSiteId BIGINT = 0;          -- 0 = all sites
DECLARE @StartDate DATE = NULL;            -- NULL = no start filter
DECLARE @EndDate DATE = NULL;              -- NULL = no end filter

WITH

InputVar AS (
    SELECT
        @ViewType AS ViewType,
        @FilterSiteId AS FilterSiteId,
        @StartDate AS StartDate,
        @EndDate AS EndDate
),

-- Get all transfers involving user's accessible sites
TransferData AS (
    SELECT
        sm.Id AS StockMovementId,
        t.FromSiteId,
        sm.DeliverySiteId AS ToSiteId,
        t.IsApproved,
        t.Comment,
        sm.CreatedAt,
        sm.Date AS ApprovedDate,
        sm.NetAmount,
        sm.TaxAmount,
        sm.GrossAmount,
        t.ApprovedByUserId,
        t.ApprovedAt,
        sm.CreatedBy

    FROM {Transfer} t
    INNER JOIN {StockMovement} sm ON t.StockMovementId = sm.Id
    WHERE sm.MovementTypeId = 2
      AND (
          ((SELECT ViewType FROM InputVar) = 'P' AND t.IsApproved = 0)
          OR
          ((SELECT ViewType FROM InputVar) = 'C' AND t.IsApproved = 1)
      )
      -- SSMS: use STRING_SPLIT for comma-separated site list
      AND (
          t.FromSiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
          OR sm.DeliverySiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
      )
      AND (
          (SELECT FilterSiteId FROM InputVar) = 0
          OR t.FromSiteId = (SELECT FilterSiteId FROM InputVar)
          OR sm.DeliverySiteId = (SELECT FilterSiteId FROM InputVar)
      )
      AND (
          (SELECT ViewType FROM InputVar) = 'P'
          OR (
              ((SELECT StartDate FROM InputVar) IS NULL OR sm.Date >= (SELECT StartDate FROM InputVar))
              AND
              ((SELECT EndDate FROM InputVar) IS NULL OR sm.Date <= (SELECT EndDate FROM InputVar))
          )
      )
),

LineSummary AS (
    SELECT
        sml.StockMovementId,
        COUNT(*) AS LineCount,
        SUM(sml.NetAmount) AS LinesNetAmount,
        SUM(sml.NetAmount) * 0.1 AS LinesGST,
        SUM(sml.NetAmount) * 1.1 AS LinesGrossAmount
    FROM {StockMovementLine} sml
    INNER JOIN TransferData td ON sml.StockMovementId = td.StockMovementId
    GROUP BY sml.StockMovementId
)

SELECT
    td.StockMovementId,
    td.FromSiteId,
    td.ToSiteId,
    fromSite.DisplayName AS FromSiteName,
    toSite.DisplayName AS ToSiteName,
    td.CreatedAt,
    td.ApprovedDate,
    ISNULL(ls.LineCount, 0) AS LineCount,

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

    td.IsApproved,
    createdByUser.Name AS CreatedByName,
    approvedByUser.Name AS ApprovedByName,
    td.ApprovedAt,
    td.Comment,

    -- Verification stats
    COUNT(*) OVER() AS Total_Rows

FROM TransferData td
INNER JOIN {Site} fromSite ON td.FromSiteId = fromSite.Id
INNER JOIN {Site} toSite ON td.ToSiteId = toSite.Id
LEFT JOIN LineSummary ls ON ls.StockMovementId = td.StockMovementId
LEFT JOIN {User} createdByUser ON td.CreatedBy = createdByUser.Id
LEFT JOIN {User} approvedByUser ON td.ApprovedByUserId = approvedByUser.Id
