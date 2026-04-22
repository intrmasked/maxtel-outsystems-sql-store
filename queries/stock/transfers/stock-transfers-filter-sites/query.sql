-- =============================================
-- Query: Stock Transfers Filter Sites
-- Purpose: Returns distinct sites appearing in the user's visible transfers
--          (both From and To sides). Used to populate the store filter dropdown.
-- Story: 1.3.1 - View Transfer List (filter dropdown)
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2026-04-13
-- =============================================

-- Input Parameters (OutSystems):
--   @SiteIds        VARCHAR   Expand Inline = YES  Comma-separated Site IDs the user has access to
--   @ViewType       VARCHAR   Expand Inline = NO   'P' = Pending, 'A' = Approved/Completed
--   @SelectedSiteId BIGINT    Expand Inline = NO   Currently selected site from sidebar (0 = all)
--   @StartDate      DATE      Expand Inline = NO   Optional: filter start date (Completed view only)
--   @EndDate        DATE      Expand Inline = NO   Optional: filter end date (Completed view only)

WITH

-- [CTE 1]: InputVar — Force OutSystems to bind parameters early
InputVar AS (
    SELECT
        @ViewType AS ViewType,
        @SelectedSiteId AS SelectedSiteId,
        @StartDate AS StartDate,
        @EndDate AS EndDate
),

-- [CTE 2]: Get all transfers matching current view filters (same as list query, minus FilterSiteId)
TransferSites AS (
    SELECT
        t.FromSiteId,
        sm.DeliverySiteId AS ToSiteId
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
      -- Sidebar site filter
      AND (
          (SELECT SelectedSiteId FROM InputVar) = 0
          OR t.FromSiteId = (SELECT SelectedSiteId FROM InputVar)
          OR sm.DeliverySiteId = (SELECT SelectedSiteId FROM InputVar)
      )
      -- Date range filter (Completed view only)
      AND (
          (SELECT ViewType FROM InputVar) = 'P'
          OR (
              ((SELECT StartDate FROM InputVar) IS NULL OR sm.Date >= (SELECT StartDate FROM InputVar))
              AND
              ((SELECT EndDate FROM InputVar) IS NULL OR sm.Date <= (SELECT EndDate FROM InputVar))
          )
      )
),

-- [CTE 3]: Unpivot From + To into a single column of distinct SiteIds
AllSiteIds AS (
    SELECT FromSiteId AS SiteId FROM TransferSites
    UNION
    SELECT ToSiteId AS SiteId FROM TransferSites
)

-- [FINAL]: Return distinct sites with names (NULL for cross-tenant)
SELECT
    a.SiteId,
    s.Name AS SiteName
FROM AllSiteIds a
LEFT JOIN {Site} s ON a.SiteId = s.Id
