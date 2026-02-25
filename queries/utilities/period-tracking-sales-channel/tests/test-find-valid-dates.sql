-- =============================================
-- Test: Find Valid Test Date Range
-- Purpose: Find a week where MOP, Delivery, AND McCafe are all non-zero
--          Use results to pick @StartDate / @EndDate for test-ssms.sql
-- Run in: SQL Sandbox (SSMS format)
-- =============================================

DECLARE @SiteId BIGINT = 3187;

-- Group by ISO week to find weeks with data across all 3 channels
WITH
MOP_ByWeek AS (
    SELECT
        DATEADD(DAY, 1 - DATEPART(WEEKDAY, p.BusDate), p.BusDate) AS WeekStart,
        SUM(spt.CountedAmount) AS MOP_Amount
    FROM {SWCPeriodTender} spt
    INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
    INNER JOIN {SWCPeriod} p   ON spt.OperatingPeriodId = p.Id
    WHERE p.SiteId = @SiteId
      AND tt.Name = 'MOP'
    GROUP BY DATEADD(DAY, 1 - DATEPART(WEEKDAY, p.BusDate), p.BusDate)
),
Delivery_ByWeek AS (
    SELECT
        DATEADD(DAY, 1 - DATEPART(WEEKDAY, p.BusDate), p.BusDate) AS WeekStart,
        SUM(spt.CountedAmount) AS Delivery_Amount
    FROM {SWCPeriodTender} spt
    INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
    INNER JOIN {SWCPeriod} p   ON spt.OperatingPeriodId = p.Id
    WHERE p.SiteId = @SiteId
      AND tt.IsDelivery = 1
    GROUP BY DATEADD(DAY, 1 - DATEPART(WEEKDAY, p.BusDate), p.BusDate)
),
McCafe_ByWeek AS (
    SELECT
        DATEADD(DAY, 1 - DATEPART(WEEKDAY, sf.CalendarDate), sf.CalendarDate) AS WeekStart,
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
    GROUP BY DATEADD(DAY, 1 - DATEPART(WEEKDAY, sf.CalendarDate), sf.CalendarDate)
)

SELECT
    m.WeekStart                             AS StartDate,
    DATEADD(DAY, 6, m.WeekStart)           AS EndDate,
    m.MOP_Amount,
    d.Delivery_Amount,
    mc.McCafe_Amount
FROM MOP_ByWeek m
INNER JOIN Delivery_ByWeek d  ON m.WeekStart = d.WeekStart
INNER JOIN McCafe_ByWeek   mc ON m.WeekStart = mc.WeekStart
WHERE m.MOP_Amount      > 0
  AND d.Delivery_Amount > 0
  AND mc.McCafe_Amount  > 0
ORDER BY m.WeekStart DESC
