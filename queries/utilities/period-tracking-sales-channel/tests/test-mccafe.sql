-- =============================================
-- Test: McCafe Sales Channel - Source Verification (Period Range)
-- Purpose: Verify McCafe data from SalesFact across a date range
--          Shows per-product, per-day breakdown with dimension checks
-- Run in: SQL Sandbox (SSMS format)
-- =============================================

DECLARE @SiteId    BIGINT = 3187;
DECLARE @StartDate DATE   = '2025-12-01';
DECLARE @EndDate   DATE   = '2025-12-07';

SELECT
    sf.CalendarDate,
    pm.ProductId                               AS ProductCode,
    pm.Name                                    AS ProductName,
    -- Dimension verification
    sf.PosId,                                  -- Must be NULL / empty
    sf.SalesFactTypeId,                        -- Must be 2
    sf.DatePeriodDimensionId,                  -- Must be 15
    sf.OperationKindId,                        -- Must be 0 / NULL
    sf.SaleTypeId,                             -- Must be 0 / NULL
    sf.NetAmount,
    sf.TransactionCount,
    SUM(sf.NetAmount)        OVER()            AS Total_NetAmount,
    SUM(sf.TransactionCount) OVER()            AS Total_TransactionCount,
    COUNT(*)                 OVER()            AS Total_Rows
FROM {SalesFact} sf
INNER JOIN {SWCPeriod} sp  ON sf.SWCPeriodId   = sp.Id
LEFT JOIN  {ProductMenu} pm ON sf.ProductMenuId  = pm.Id
LEFT JOIN  {BO_MenuItem} mi ON pm.ProductId       = mi.MIN
                            AND pm.ConceptId       = mi.ConceptId
                            AND mi.IsMcCafe        = 1
WHERE sp.SiteId = @SiteId
  AND sp.BusDate BETWEEN @StartDate AND @EndDate
  AND ISNULL(sf.PosId, '')          = ''
  AND ISNULL(sf.SalesFactTypeId, 0) = 2
  AND sf.DatePeriodDimensionId      = 15
  AND ISNULL(sf.OperationKindId, 0) = 0
  AND ISNULL(sf.SaleTypeId, 0)      = 0
  AND sf.TenderTypeId               IS NULL
  AND sf.OperationId                IS NULL
  AND sf.SWCCashDrawerId            IS NULL
  AND mi.IsMcCafe                   = 1
ORDER BY sf.CalendarDate, pm.Name
