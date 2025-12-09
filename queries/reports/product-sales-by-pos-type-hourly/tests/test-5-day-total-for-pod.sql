-- =============================================
-- Test 5: Day Total for Specific Pod
-- Purpose: Shows total sales for the specified pod for the entire day
-- Usage: Set @Pod to 'CSO', 'FC', 'DT', etc.
-- Created: 2025-12-09
-- =============================================

-- Test Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-12-08';
DECLARE @Pod VARCHAR(50) = 'CSO';  -- Set to specific pod: 'CSO', 'FC', 'DT'

IF @Pod IS NOT NULL AND @Pod <> 'Total'
BEGIN
    SELECT
        @Date AS Date,
        @Pod AS Pod,
        SUM(NetAmount) AS DayTotalSales,
        SUM(TransactionCount) AS DayTotalGuestCount,
        CASE WHEN SUM(TransactionCount) = 0 THEN 0
             ELSE SUM(NetAmount) / SUM(TransactionCount) END AS DayAvgCheck
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
      AND Pod = @Pod
      AND Pod IS NOT NULL AND Pod <> '';
END
ELSE
BEGIN
    PRINT 'Error: @Pod must be set to a specific pod code (CSO, FC, DT, etc.)';
END;
