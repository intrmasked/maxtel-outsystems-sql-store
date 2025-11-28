-- =============================================
-- Test Query: SalesFact Daily Query
-- Purpose: Simple SalesFact query for a single day to test filters
-- Target: SQL Server 2014+
-- Created: 2025-11-28
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 3187;  -- Default test site
DECLARE @Date DATE = '2025-11-28';

-- Main Query
SELECT
    sf.SiteId,
    sf.CalendarDate,
    sf.DateTime,
    sf.Id,
    sf.SalesFactTypeId,
    sf.DatePeriodDimensionId,
    sf.PosId,
    sf.Pod,
    sf.SWCCashDrawerId,
    sf.CashDrawerId,
    sf.TenderTypeId,
    sf.Quantity,
    sf.NetAmount,
    sf.TaxAmount,
    sf.NetBeforeDiscount,
    sf.TaxBeforeDiscount,
    sf.RoundingAmount,
    sf.TransactionCount,
    sf.ProductMenuId,
    sf.OperationId,
    sf.OperationKindId,
    sf.ProductSaleTypeId,
    sf.SaleTypeId,
    sf.SourceFileId,
    sf.SWCPeriodId
FROM {SalesFact} sf
WHERE sf.SiteId = @SiteId
    AND sf.CalendarDate = @Date
    AND sf.DatePeriodDimensionId = 15
    AND sf.PosId <> ''
    AND sf.Pod <> ''
    AND sf.ProductMenuId IS NULL
    AND sf.ProductSaleTypeId = 1
    AND sf.TenderTypeId IS NULL
    AND sf.OperationId IS NULL
    AND sf.OperationKindId IS NULL
    AND sf.SWCCashDrawerId IS NULL
    AND sf.SaleTypeId IS NULL
    AND sf.PosId IS NOT NULL
    AND sf.ProductSaleTypeId IS NOT NULL
ORDER BY sf.CalendarDate, sf.DateTime, sf.PosId;
