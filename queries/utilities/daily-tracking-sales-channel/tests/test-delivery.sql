-- =============================================
-- Test: Delivery Sales Channel - Source Verification
-- Purpose: Verify Delivery data from SWCPeriodTender
--          filtered by TenderType.IsDelivery = 1
--          Shows each delivery tender type broken out
--          so we can confirm which ones are included
-- Run in: SQL Sandbox (SSMS format)
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-12-04';

WITH
TargetPeriod AS (
    SELECT Id AS OperatingPeriodId
    FROM {SWCPeriod}
    WHERE SiteId = @SiteId
      AND BusDate = @Date
)

-- Show each delivery tender row individually with flags so we can see
-- exactly which tenders are contributing and what their flags are
SELECT
    spt.OperatingPeriodId,
    tt.TenderTypeId,
    tt.Name                                    AS TenderName,
    tt.IsDelivery,
    tt.IsMobileEFTPos,                         -- MOP will have this = 1
    spt.CountedAmount,
    spt.TransactionCount,
    -- Running totals across all delivery tenders
    SUM(spt.CountedAmount)    OVER()           AS Total_CountedAmount,
    SUM(spt.TransactionCount) OVER()           AS Total_TransactionCount,
    COUNT(*)                  OVER()           AS Total_Rows
FROM {SWCPeriodTender} spt
INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
INNER JOIN TargetPeriod tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
WHERE tt.IsDelivery = 1
ORDER BY tt.TenderTypeId
