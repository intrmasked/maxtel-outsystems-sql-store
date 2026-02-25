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
    mi.IsMcCafe,
    -- Dimension flags — all must be NULL (confirms no double-counting)
    sf.TenderTypeId,                           -- Must be NULL
    sf.OperationId,                            -- Must be NULL
    sf.OperationKindId,                        -- Must be NULL
    sf.SWCCashDrawerId,                        -- Must be NULL
    sf.SaleTypeId,                             -- Must be NULL
    sf.ProductSaleTypeId,                      -- Must be 1
    sf.PosId,                                  -- Must be non-zero
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
WHERE sp.SiteId = @SiteId
  AND sf.CalendarDate BETWEEN @StartDate AND @EndDate
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
ORDER BY sf.CalendarDate, pm.Name
