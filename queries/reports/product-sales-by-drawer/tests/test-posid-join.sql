-- =============================================
-- Test Query: PosId JOIN Diagnostic
-- Purpose: Check if PosId values match between SWCCashDrawer and SalesFact
-- Target: SQL Server 2014+
-- Created: 2025-11-28
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-28';

-- Check PosId from both tables
SELECT
    'CashDrawer' AS Source,
    cd.PosId,
    COUNT(*) AS RecordCount
FROM {SWCPeriod} p
INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
WHERE p.SiteId = @SiteId
    AND p.BusDate = @Date
GROUP BY cd.PosId

UNION ALL

SELECT
    'SalesFact' AS Source,
    sf.PosId,
    COUNT(*) AS RecordCount
FROM {SalesFact} sf
WHERE sf.SiteId = @SiteId
    AND sf.CalendarDate = @Date
    AND sf.DatePeriodDimensionId = 15
    AND sf.PosId <> ''
    AND sf.PosId IS NOT NULL
    AND sf.ProductSaleTypeId IS NOT NULL
    AND sf.ProductMenuId IS NULL
    AND sf.TenderTypeId IS NULL
    AND sf.OperationId IS NULL
    AND sf.OperationKindId IS NULL
    AND sf.SWCCashDrawerId IS NULL
    AND sf.SaleTypeId IS NULL
GROUP BY sf.PosId

ORDER BY Source, PosId;
