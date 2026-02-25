-- =============================================
-- Test: Delivery Sales Channel - Source Verification (Period Range)
-- Purpose: Verify Delivery data from SWCPeriodTender across a date range
--          Broken out per tender type per day
-- Run in: SQL Sandbox (SSMS format)
-- =============================================

DECLARE @SiteId    BIGINT = 3187;
DECLARE @StartDate DATE   = '2025-12-01';
DECLARE @EndDate   DATE   = '2025-12-07';

WITH
TargetPeriods AS (
    SELECT Id AS OperatingPeriodId, BusDate
    FROM {SWCPeriod}
    WHERE SiteId = @SiteId
      AND BusDate BETWEEN @StartDate AND @EndDate
)

SELECT
    tp.BusDate,
    tt.TenderTypeId,
    tt.Name                                    AS TenderName,
    tt.IsDelivery,
    tt.IsMobileEFTPos,
    spt.CountedAmount,
    spt.TransactionCount,
    SUM(spt.CountedAmount)    OVER()           AS Total_CountedAmount,
    SUM(spt.TransactionCount) OVER()           AS Total_TransactionCount,
    COUNT(*)                  OVER()           AS Total_Rows
FROM {SWCPeriodTender} spt
INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
INNER JOIN TargetPeriods tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
WHERE tt.IsDelivery = 1
ORDER BY tp.BusDate, tt.TenderTypeId
