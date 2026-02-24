-- =============================================
-- Query: Daily Tracking Report - Sales Channels
-- Purpose: Returns 3 Sales Channel rows for a given business date and site:
--          1. MOP       - from SWCPeriodTender where TenderType.IsMobileEFTPos = 1
--          2. Delivery  - from SWCPeriodTender where TenderType.IsDelivery = 1
--          3. McCafe    - from SalesFact joined to ProductMenu + BO_MenuItem where IsMcCafe = 1
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2026-02-24
-- =============================================

/*
    OUTSYSTEMS PARAMETERS:
    - SiteId (LongInteger) → Expand Inline = No
    - Date   (Date)        → Expand Inline = No
*/

WITH

-- [STEP 1]: Get the Operating Period for this site/date
-- SWCPeriodTender uses OperatingPeriodId, so we need the period first
TargetPeriod AS (
    SELECT Id AS OperatingPeriodId
    FROM {SWCPeriod}
    WHERE SiteId = @SiteId
      AND BusDate = @Date
),

-- [STEP 2]: MOP Sales Channel
-- Source: SWCPeriodTender filtered by TenderType.IsMobileEFTPos = 1
-- Business Date = SWCPeriod.BusDate
MOP_Data AS (
    SELECT
        ISNULL(SUM(spt.CountedAmount), 0)    AS Amount,
        ISNULL(SUM(spt.TransactionCount), 0) AS GuestCount
    FROM {SWCPeriodTender} spt
    INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
    INNER JOIN TargetPeriod tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
    WHERE tt.Name = 'MOP'
),

-- [STEP 3]: Delivery Sales Channel
-- Source: SWCPeriodTender filtered by TenderType.IsDelivery = 1
-- Includes: MOP, DoorDash, UberEats, DeliverEasy
-- Business Date = SWCPeriod.BusDate
Delivery_Data AS (
    SELECT
        ISNULL(SUM(spt.CountedAmount), 0)    AS Amount,
        ISNULL(SUM(spt.TransactionCount), 0) AS GuestCount
    FROM {SWCPeriodTender} spt
    INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
    INNER JOIN TargetPeriod tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
    WHERE tt.IsDelivery = 1
),

-- [STEP 4]: McCafe Sales Channel
-- Source: SalesFact joined to ProductMenu + BO_MenuItem where IsMcCafe = 1
-- Calendar Date = SalesFact.CalendarDate
-- CRITICAL: ProductMenuId must NOT be NULL (we're filtering by menu item)
-- CRITICAL: All other unused dimension IDs must be NULL to prevent double-counting
McCafe_Data AS (
    SELECT
        ISNULL(SUM(sf.NetAmount), 0)        AS Amount,
        ISNULL(SUM(sf.TransactionCount), 0) AS GuestCount
    FROM {SalesFact} sf
    INNER JOIN {ProductMenu} pm ON sf.ProductMenuId = pm.Id
    INNER JOIN {BO_MenuItem} mi ON pm.ProductId = mi.MIN
    WHERE sf.SiteId = @SiteId
      AND sf.CalendarDate = @Date
      AND sf.DatePeriodDimensionId = 15
      AND mi.IsMcCafe = 1
      -- Mandatory dimension filters (null out all unused dims)
      AND sf.TenderTypeId IS NULL
      AND sf.OperationId IS NULL
      AND sf.OperationKindId IS NULL
      AND sf.SWCCashDrawerId IS NULL
      AND sf.SaleTypeId IS NULL
      AND sf.ProductSaleTypeId = 1
      AND sf.PosId IS NOT NULL
      AND sf.PosId <> 0
)

-- [STEP 5]: Final Output - 3 rows, one per Sales Channel
SELECT
    'MOP'                       AS Channel,
    m.Amount                    AS NetAmount,
    CAST(m.GuestCount AS DECIMAL(18,2)) AS GuestCount,
    CASE
        WHEN m.GuestCount = 0 THEN CAST(0 AS DECIMAL(18,2))
        ELSE CAST(m.Amount / m.GuestCount AS DECIMAL(18,2))
    END                         AS AverageCheck
FROM MOP_Data m

UNION ALL

SELECT
    'Delivery'                  AS Channel,
    d.Amount                    AS NetAmount,
    CAST(d.GuestCount AS DECIMAL(18,2)) AS GuestCount,
    CASE
        WHEN d.GuestCount = 0 THEN CAST(0 AS DECIMAL(18,2))
        ELSE CAST(d.Amount / d.GuestCount AS DECIMAL(18,2))
    END                         AS AverageCheck
FROM Delivery_Data d

UNION ALL

SELECT
    'McCafe'                    AS Channel,
    mc.Amount                   AS NetAmount,
    CAST(mc.GuestCount AS DECIMAL(18,2)) AS GuestCount,
    CASE
        WHEN mc.GuestCount = 0 THEN CAST(0 AS DECIMAL(18,2))
        ELSE CAST(mc.Amount / mc.GuestCount AS DECIMAL(18,2))
    END                         AS AverageCheck
FROM McCafe_Data mc;
