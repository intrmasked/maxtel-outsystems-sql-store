-- =============================================
-- Test: Find Valid Test Dates
-- Purpose: Find dates where MOP, Delivery, AND McCafe
--          are all non-zero for a given site.
--          Use the results to pick a good @Date for testing.
-- Run in: SQL Sandbox (SSMS format)
-- =============================================

DECLARE @SiteId BIGINT = 3187;

WITH

-- MOP amounts aggregated by business date
MOP_ByDate AS (
    SELECT
        p.BusDate,
        SUM(spt.CountedAmount) AS MOP_Amount
    FROM {SWCPeriodTender} spt
    INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
    INNER JOIN {SWCPeriod} p   ON spt.OperatingPeriodId = p.Id
    WHERE p.SiteId = @SiteId
      AND tt.Name = 'MOP'
    GROUP BY p.BusDate
),

-- Delivery amounts aggregated by business date
Delivery_ByDate AS (
    SELECT
        p.BusDate,
        SUM(spt.CountedAmount) AS Delivery_Amount
    FROM {SWCPeriodTender} spt
    INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
    INNER JOIN {SWCPeriod} p   ON spt.OperatingPeriodId = p.Id
    WHERE p.SiteId = @SiteId
      AND tt.IsDelivery = 1
    GROUP BY p.BusDate
),

-- McCafe amounts aggregated by calendar date
McCafe_ByDate AS (
    SELECT
        sf.CalendarDate AS BusDate,
        SUM(sf.NetAmount) AS McCafe_Amount
    FROM {SalesFact} sf
    INNER JOIN {SWCPeriod} sp  ON sf.SWCPeriodId   = sp.Id
    LEFT JOIN  {ProductMenu} pm ON sf.ProductMenuId  = pm.Id
    LEFT JOIN  {BO_MenuItem} mi ON pm.ProductId       = mi.MIN
                                AND pm.ConceptId       = mi.ConceptId
    WHERE sp.SiteId = @SiteId
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
    GROUP BY sf.CalendarDate
)

-- Join all three on date, only return dates where all three are non-zero
SELECT
    m.BusDate,
    m.MOP_Amount,
    d.Delivery_Amount,
    mc.McCafe_Amount
FROM MOP_ByDate m
INNER JOIN Delivery_ByDate  d  ON m.BusDate = d.BusDate
INNER JOIN McCafe_ByDate    mc ON m.BusDate = mc.BusDate
WHERE m.MOP_Amount      > 0
  AND d.Delivery_Amount > 0
  AND mc.McCafe_Amount  > 0
ORDER BY m.BusDate DESC
