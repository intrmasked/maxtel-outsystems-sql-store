-- =============================================
-- Test Query: GST vs Gross Sales Comparison
-- Purpose: Compare GST totals from SalesFact vs Gross Sales from Cash Drawer
-- Target: SQL Server 2014+
-- Created: 2025-11-28
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-28';

-- Get totals from both sources
SELECT
    'Cash Drawer GT' AS Source,
    SUM(cd.FinalGT - cd.InitialGT) AS TotalDifference,
    0 AS GST,
    SUM(cd.FinalGT - cd.InitialGT) AS GrossSales
FROM {SWCPeriod} p
INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
WHERE p.SiteId = @SiteId
    AND p.BusDate = @Date

UNION ALL

SELECT
    'SalesFact GST' AS Source,
    0 AS TotalDifference,
    SUM(TaxAmount) AS GST,
    0 AS GrossSales
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

UNION ALL

SELECT
    'Product Sales' AS Source,
    0 AS TotalDifference,
    0 AS GST,
    SUM(NetAmount) AS GrossSales
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND PosId <> ''
    AND Pod <> ''
    AND PosId IS NOT NULL
    AND ProductSaleTypeId = 1
    AND ProductSaleTypeId IS NOT NULL
    AND ProductMenuId IS NULL
    AND TenderTypeId IS NULL
    AND OperationId IS NULL
    AND OperationKindId IS NULL
    AND SWCCashDrawerId IS NULL
    AND SaleTypeId IS NULL

UNION ALL

SELECT
    'Non-Product Sales' AS Source,
    0 AS TotalDifference,
    0 AS GST,
    SUM(NetAmount) AS GrossSales
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND PosId <> ''
    AND Pod <> ''
    AND PosId IS NOT NULL
    AND ProductSaleTypeId = 2
    AND ProductSaleTypeId IS NOT NULL
    AND ProductMenuId IS NULL
    AND TenderTypeId IS NULL
    AND OperationId IS NULL
    AND OperationKindId IS NULL
    AND SWCCashDrawerId IS NULL
    AND SaleTypeId IS NULL;
