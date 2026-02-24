-- =============================================
-- Test: McCafe Sales Channel - Source Verification
-- Purpose: Verify McCafe data from SalesFact
--          joined to ProductMenu + BO_MenuItem where IsMcCafe = 1
--          Shows per-product breakdown so we can confirm
--          which items are being included and dimension filters are correct
-- Run in: SQL Sandbox (SSMS format)
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-12-04';

-- Show McCafe sales per product item with window-function totals
-- Verify: all unused dims are NULL, only product sales (ProductSaleTypeId = 1)
SELECT
    pm.ProductId                               AS ProductCode,
    pm.Name                                    AS ProductName,
    mi.IsMcCafe,
    -- Dimension flags — all should be NULL (confirms no double-counting)
    sf.TenderTypeId,                           -- Must be NULL
    sf.OperationId,                            -- Must be NULL
    sf.OperationKindId,                        -- Must be NULL
    sf.SWCCashDrawerId,                        -- Must be NULL
    sf.SaleTypeId,                             -- Must be NULL
    sf.ProductSaleTypeId,                      -- Must be 1
    sf.PosId,                                  -- Must be NOT NULL / non-zero
    -- Per-row values
    sf.NetAmount,
    sf.TransactionCount,
    -- Window totals for the whole result set
    SUM(sf.NetAmount)        OVER()            AS Total_NetAmount,
    SUM(sf.TransactionCount) OVER()            AS Total_TransactionCount,
    COUNT(*)                 OVER()            AS Total_Rows
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
ORDER BY pm.Name
