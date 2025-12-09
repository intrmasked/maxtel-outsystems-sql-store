-- =============================================
-- Test 2: Grand Total by Pod (Across All Dates)
-- Purpose: Shows cumulative totals per pod
-- Created: 2025-12-09
-- =============================================

-- Test Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';
DECLARE @Pod VARCHAR(50) = NULL;  -- NULL = All Pods, 'CSO' = Kiosk only, 'FC' = Counter only, 'DT' = Drive-Thru only

SELECT
    Pod,
    SUM(NetAmount) AS TotalSales,
    SUM(TransactionCount) AS TotalGuestCount,
    CASE WHEN SUM(TransactionCount) = 0 THEN 0
         ELSE SUM(NetAmount) / SUM(TransactionCount) END AS AvgCheck
FROM {SalesFact}
WHERE SiteId = @SiteId
  AND CalendarDate BETWEEN @StartDate AND @EndDate
  AND DatePeriodDimensionId = 15
  AND ProductMenuId IS NULL
  AND ProductSaleTypeId = 1
  AND TenderTypeId IS NULL
  AND OperationId IS NULL
  AND OperationKindId IS NULL
  AND SWCCashDrawerId IS NULL
  AND SaleTypeId IS NULL
  AND PosId IS NOT NULL
  AND Pod IN ('FC', 'DT', 'CSO')
  AND Pod IS NOT NULL AND Pod <> ''
  AND (@Pod IS NULL OR Pod = @Pod)  -- Filter by pod if specified
GROUP BY Pod
ORDER BY Pod;
