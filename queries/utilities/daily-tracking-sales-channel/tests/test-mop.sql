-- =============================================
-- Test: MOP Sales Channel - Source Verification
-- Purpose: Verify MOP data pulled from SWCPeriodTender
--          filtered by TenderType.IsMobileEFTPos = 1
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

-- Show each MOP tender row with running totals so we can verify the aggregate
SELECT
    spt.OperatingPeriodId,
    tt.TenderTypeId,
    tt.Name                                    AS TenderName,
    tt.IsMobileEFTPos,                         -- For reference only (MOP filter is by Name)
    spt.CountedAmount,
    spt.TransactionCount,
    -- Running totals for verification
    SUM(spt.CountedAmount)    OVER()           AS Total_CountedAmount,
    SUM(spt.TransactionCount) OVER()           AS Total_TransactionCount,
    COUNT(*)                  OVER()           AS Total_Rows
FROM {SWCPeriodTender} spt
INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
INNER JOIN TargetPeriod tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
WHERE tt.Name = 'MOP'
ORDER BY tt.TenderTypeId
