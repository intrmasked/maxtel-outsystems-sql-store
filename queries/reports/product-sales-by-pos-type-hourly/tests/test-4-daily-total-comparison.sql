-- =============================================
-- Test 4: Compare Daily Total with product-sales-by-pos Query
-- Purpose: Verify hourly daily total matches product-sales-by-pos for same date
-- Created: 2025-12-09
-- =============================================

-- Test Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-12-08';

SELECT
    @Date AS Date,
    SUM(NetAmount) AS TotalSales,
    SUM(TransactionCount) AS TotalGuestCount,
    CASE WHEN SUM(TransactionCount) = 0 THEN 0
         ELSE SUM(NetAmount) / SUM(TransactionCount) END AS AvgCheck
FROM {SalesFact}
WHERE SiteId = @SiteId
  AND CalendarDate = @Date
  AND DatePeriodDimensionId = 15
  AND ProductSaleTypeId = 1
  AND ProductMenuId IS NULL
  AND TenderTypeId IS NULL
  AND OperationId IS NULL
  AND OperationKindId IS NULL
  AND SWCCashDrawerId IS NULL
  AND SaleTypeId IS NULL
  AND PosId IS NOT NULL
  AND Pod IN ('FC', 'DT', 'CSO')
  AND Pod IS NOT NULL AND Pod <> '';
