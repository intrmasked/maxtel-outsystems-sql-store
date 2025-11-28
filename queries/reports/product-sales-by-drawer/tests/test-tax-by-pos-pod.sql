-- =============================================
-- Test Query: Tax Amounts by PosId and Pod
-- Purpose: Check GST/Tax amounts per POS-Pod combination from SalesFact
-- Target: SQL Server 2014+
-- Created: 2025-11-28
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-28';

-- Get Tax amounts grouped by PosId and Pod
SELECT
    PosId,
    Pod,
    COUNT(*) AS RecordCount,
    SUM(TaxAmount) AS TotalTax,
    SUM(NetAmount) AS TotalNet,
    SUM(TaxAmount) + SUM(NetAmount) AS GrossTotal,
    ProductSaleTypeId
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND PosId <> ''
    AND Pod <> ''
    AND PosId IS NOT NULL
    AND ProductSaleTypeId IS NOT NULL
    AND ProductMenuId IS NULL
    AND TenderTypeId IS NULL
    AND OperationId IS NULL
    AND OperationKindId IS NULL
    AND SWCCashDrawerId IS NULL
    AND SaleTypeId IS NULL
GROUP BY PosId, Pod, ProductSaleTypeId
ORDER BY PosId, Pod, ProductSaleTypeId;
