-- =============================================
-- Test: SalesFact Validation
-- Purpose: Verify SalesFact data is being pulled correctly with proper filters
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-28';

PRINT '=== TEST 1: SalesFact Records Count by POS/Pod ==='
-- Count of SalesFact records per POS/Pod with all filters applied
SELECT
    PosId,
    Pod,
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN ProductSaleTypeId = 1 THEN 1 ELSE 0 END) AS ProductRecords,
    SUM(CASE WHEN ProductSaleTypeId = 2 THEN 1 ELSE 0 END) AS NonProductRecords
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
GROUP BY PosId, Pod
ORDER BY PosId;

PRINT ''
PRINT '=== TEST 2: SalesFact Amounts Detail by ProductSaleTypeId ==='
-- Detailed amounts per POS/Pod by product type
SELECT
    PosId,
    Pod,
    ProductSaleTypeId,
    COUNT(*) AS RecordCount,
    SUM(TaxAmount) AS TotalTax,
    SUM(NetAmount) AS TotalNetAmount,
    SUM(GrossAmount) AS TotalGrossAmount
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
ORDER BY PosId, ProductSaleTypeId;

PRINT ''
PRINT '=== TEST 3: SalesFact Aggregated (Main Query Pattern) ==='
-- Exactly as used in main query - single aggregation
SELECT
    PosId,
    Pod,
    SUM(TaxAmount) AS TotalTax,
    SUM(CASE WHEN ProductSaleTypeId = 1 THEN NetAmount ELSE 0 END) AS ProdSales,
    SUM(CASE WHEN ProductSaleTypeId = 2 THEN NetAmount ELSE 0 END) AS NonProdSales,
    -- Verification columns
    SUM(CASE WHEN ProductSaleTypeId = 1 THEN 1 ELSE 0 END) AS ProdRecordCount,
    SUM(CASE WHEN ProductSaleTypeId = 2 THEN 1 ELSE 0 END) AS NonProdRecordCount,
    COUNT(*) AS TotalRecordCount
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
GROUP BY PosId, Pod
ORDER BY PosId;

PRINT ''
PRINT '=== TEST 4: Verify Dimension Filters ==='
-- Check if there are any records that would be excluded by dimension filters
SELECT
    'Records with ProductMenuId NOT NULL' AS FilterCheck,
    COUNT(*) AS RecordCount
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND PosId <> '' AND Pod <> '' AND PosId IS NOT NULL
    AND ProductSaleTypeId IS NOT NULL
    AND ProductMenuId IS NOT NULL  -- Should be excluded

UNION ALL

SELECT
    'Records with TenderTypeId NOT NULL' AS FilterCheck,
    COUNT(*) AS RecordCount
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND PosId <> '' AND Pod <> '' AND PosId IS NOT NULL
    AND ProductSaleTypeId IS NOT NULL
    AND TenderTypeId IS NOT NULL  -- Should be excluded

UNION ALL

SELECT
    'Records with OperationId NOT NULL' AS FilterCheck,
    COUNT(*) AS RecordCount
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND PosId <> '' AND Pod <> '' AND PosId IS NOT NULL
    AND ProductSaleTypeId IS NOT NULL
    AND OperationId IS NOT NULL  -- Should be excluded

UNION ALL

SELECT
    'Records INCLUDED (all dimension filters correct)' AS FilterCheck,
    COUNT(*) AS RecordCount
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND PosId <> '' AND Pod <> '' AND PosId IS NOT NULL
    AND ProductSaleTypeId IS NOT NULL
    AND ProductMenuId IS NULL
    AND TenderTypeId IS NULL
    AND OperationId IS NULL
    AND OperationKindId IS NULL
    AND SWCCashDrawerId IS NULL
    AND SaleTypeId IS NULL;

PRINT ''
PRINT '=== TEST 5: Compare POS Lists - Cash Drawer vs SalesFact ==='
-- Ensure all POS terminals in cash drawer also have SalesFact data
SELECT
    'Cash Drawer POS Count' AS Source,
    COUNT(DISTINCT cd.PosId) AS PosCount
FROM {SWCPeriod} p
INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
WHERE p.SiteId = @SiteId AND p.BusDate = @Date

UNION ALL

SELECT
    'SalesFact POS Count' AS Source,
    COUNT(DISTINCT PosId) AS PosCount
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND PosId <> '' AND PosId IS NOT NULL
    AND ProductSaleTypeId IS NOT NULL
    AND ProductMenuId IS NULL
    AND TenderTypeId IS NULL
    AND OperationId IS NULL
    AND OperationKindId IS NULL
    AND SWCCashDrawerId IS NULL
    AND SaleTypeId IS NULL;

PRINT ''
PRINT '=== TEST 6: POS Terminals Missing from SalesFact ==='
-- Show which POS terminals have cash drawer data but no SalesFact data
SELECT DISTINCT
    cd.PosId,
    pt.Pod,
    'Missing in SalesFact' AS Issue
FROM {SWCPeriod} p
INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
INNER JOIN {SWCPosTerminal} pt ON cd.PosId = pt.PosId AND cd.OperatingPeriodId = pt.OperatingPeriodId
WHERE p.SiteId = @SiteId AND p.BusDate = @Date
    AND NOT EXISTS (
        SELECT 1
        FROM {SalesFact} sf
        WHERE sf.SiteId = @SiteId
            AND sf.CalendarDate = @Date
            AND sf.DatePeriodDimensionId = 15
            AND sf.PosId = cd.PosId
            AND sf.Pod = pt.Pod
            AND sf.PosId <> '' AND sf.PosId IS NOT NULL
            AND sf.ProductSaleTypeId IS NOT NULL
            AND sf.ProductMenuId IS NULL
            AND sf.TenderTypeId IS NULL
            AND sf.OperationId IS NULL
            AND sf.OperationKindId IS NULL
            AND sf.SWCCashDrawerId IS NULL
            AND sf.SaleTypeId IS NULL
    );

PRINT ''
PRINT '=== TEST 7: Total Tax Amount Verification ==='
-- Compare total tax from different grouping levels
SELECT
    'By PosId, Pod (Main Query Pattern)' AS GroupingLevel,
    SUM(TotalTax) AS TotalGST
FROM (
    SELECT
        PosId,
        Pod,
        SUM(TaxAmount) AS TotalTax
    FROM {SalesFact}
    WHERE SiteId = @SiteId
        AND CalendarDate = @Date
        AND DatePeriodDimensionId = 15
        AND PosId <> '' AND Pod <> '' AND PosId IS NOT NULL
        AND ProductSaleTypeId IS NOT NULL
        AND ProductMenuId IS NULL
        AND TenderTypeId IS NULL
        AND OperationId IS NULL
        AND OperationKindId IS NULL
        AND SWCCashDrawerId IS NULL
        AND SaleTypeId IS NULL
    GROUP BY PosId, Pod
) AS ByPos

UNION ALL

SELECT
    'Direct Aggregate (No Grouping)' AS GroupingLevel,
    SUM(TaxAmount) AS TotalGST
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND PosId <> '' AND Pod <> '' AND PosId IS NOT NULL
    AND ProductSaleTypeId IS NOT NULL
    AND ProductMenuId IS NULL
    AND TenderTypeId IS NULL
    AND OperationId IS NULL
    AND OperationKindId IS NULL
    AND SWCCashDrawerId IS NULL
    AND SaleTypeId IS NULL;
