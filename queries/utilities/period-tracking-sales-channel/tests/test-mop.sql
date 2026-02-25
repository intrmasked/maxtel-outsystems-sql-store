-- =============================================
-- Test: MOP Sales Channel - Source Verification (Period Range)
-- Purpose: Verify MOP data from SWCPeriodTender across a date range
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

-- Show per-day MOP totals so we can verify the range aggregate
SELECT
    tp.BusDate,
    tt.TenderTypeId,
    tt.Name                                    AS TenderName,
    spt.CountedAmount,
    spt.TransactionCount,
    SUM(spt.CountedAmount)    OVER()           AS Total_CountedAmount,
    SUM(spt.TransactionCount) OVER()           AS Total_TransactionCount,
    COUNT(*)                  OVER()           AS Total_Rows
FROM {SWCPeriodTender} spt
INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
INNER JOIN TargetPeriods tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
WHERE tt.Name = 'MOP'
ORDER BY tp.BusDate
