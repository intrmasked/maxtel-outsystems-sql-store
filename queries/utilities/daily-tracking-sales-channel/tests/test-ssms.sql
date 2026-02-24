-- =============================================
-- Test: SSMS Version - DailyTrackingSalesChannel
-- Purpose: Full query with DECLARE params for testing in SSMS / SQL Sandbox
--          Copy the main query.sql and add DECLARE statements at the top
-- Run in: SQL Sandbox (SSMS format)
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-12-04';

WITH

-- [STEP 1]: Get the Operating Period for this site/date
TargetPeriod AS (
    SELECT Id AS OperatingPeriodId
    FROM {SWCPeriod}
    WHERE SiteId = @SiteId
      AND BusDate = @Date
),

-- [STEP 2]: MOP Sales Channel
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
      AND sf.TenderTypeId IS NULL
      AND sf.OperationId IS NULL
      AND sf.OperationKindId IS NULL
      AND sf.SWCCashDrawerId IS NULL
      AND sf.SaleTypeId IS NULL
      AND sf.ProductSaleTypeId = 1
      AND sf.PosId IS NOT NULL
      AND sf.PosId <> 0
)

SELECT 'MOP'      AS Channel, m.Amount AS NetAmount, CAST(m.GuestCount AS DECIMAL(18,2)) AS GuestCount, CASE WHEN m.GuestCount = 0 THEN CAST(0 AS DECIMAL(18,2)) ELSE CAST(m.Amount / m.GuestCount AS DECIMAL(18,2)) END AS AverageCheck FROM MOP_Data m
UNION ALL
SELECT 'Delivery' AS Channel, d.Amount, CAST(d.GuestCount AS DECIMAL(18,2)), CASE WHEN d.GuestCount = 0 THEN CAST(0 AS DECIMAL(18,2)) ELSE CAST(d.Amount / d.GuestCount AS DECIMAL(18,2)) END FROM Delivery_Data d
UNION ALL
SELECT 'McCafe'   AS Channel, mc.Amount, CAST(mc.GuestCount AS DECIMAL(18,2)), CASE WHEN mc.GuestCount = 0 THEN CAST(0 AS DECIMAL(18,2)) ELSE CAST(mc.Amount / mc.GuestCount AS DECIMAL(18,2)) END FROM McCafe_Data mc
