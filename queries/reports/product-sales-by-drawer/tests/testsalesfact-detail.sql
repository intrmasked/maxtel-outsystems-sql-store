-- =============================================
-- Test Query: SalesFact Detail by POS
-- Purpose: Check NetAmount, TaxAmount, and ProductSaleTypeId per POS
-- Target: SQL Server 2014+
-- Created: 2025-11-28
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 3187;  -- Default test site
DECLARE @Date DATE = '2025-11-28';

-- Main Query
SELECT
    sf.PosId,
    sf.Pod,
    sf.DateTime,
    sf.NetAmount,
    sf.TaxAmount,
    sf.ProductSaleTypeId,
    sf.SWCPeriodId
FROM {SalesFact} sf
WHERE sf.SiteId = @SiteId
    AND sf.CalendarDate = @Date
    AND sf.DatePeriodDimensionId = 15
    AND sf.PosId <> ''
    AND sf.Pod <> ''
    AND sf.PosId IS NOT NULL
    AND sf.ProductSaleTypeId IS NOT NULL
    AND sf.ProductMenuId IS NULL
    AND sf.TenderTypeId IS NULL
    AND sf.OperationId IS NULL
    AND sf.OperationKindId IS NULL
    AND sf.SWCCashDrawerId IS NULL
    AND sf.SaleTypeId IS NULL
ORDER BY sf.PosId, sf.DateTime;
