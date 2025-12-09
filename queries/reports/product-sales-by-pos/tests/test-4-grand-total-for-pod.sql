-- =============================================
-- Test 4: Grand Total for Specific Pod
-- Purpose: Shows the grand total for the specified pod across all dates
-- Usage: Set @Pod to 'CSO', 'FC', 'DT', etc.
-- Created: 2025-12-09
-- =============================================

-- Test Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';
DECLARE @Pod VARCHAR(50) = 'CSO';  -- Set to specific pod: 'CSO', 'FC', 'DT'

IF @Pod IS NOT NULL AND @Pod <> 'Total'
BEGIN
    SELECT
        @StartDate AS StartDate,
        @EndDate AS EndDate,
        @Pod AS Pod,
        SUM(NetAmount) AS GrandTotalSales,
        SUM(TransactionCount) AS GrandTotalGuestCount,
        CASE WHEN SUM(TransactionCount) = 0 THEN 0
             ELSE SUM(NetAmount) / SUM(TransactionCount) END AS GrandAvgCheck
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
      AND Pod = @Pod
      AND Pod IS NOT NULL AND Pod <> '';
END
ELSE
BEGIN
    PRINT 'Error: @Pod must be set to a specific pod code (CSO, FC, DT, etc.)';
END;
