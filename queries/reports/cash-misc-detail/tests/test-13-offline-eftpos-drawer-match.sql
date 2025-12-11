-- =============================================
-- Test: Offline Eftpos Drawer Match Diagnostic
-- Purpose: Find which drawer has Offline Eftpos and verify it appears in main query
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-12-04';

-- Get Period ID
DECLARE @PeriodId BIGINT;
SELECT @PeriodId = Id FROM {SWCPeriod} WHERE SiteId = @SiteId AND BusDate = @Date;

-- Show which drawer(s) have Offline Eftpos (TenderTypeId = 9)
SELECT
    cd.PosId,
    cd.OperatorUserId,
    u.Name AS CashierName,
    pt.Pod,
    cdt.TenderTypeId,
    tt.Name AS TenderTypeName,
    cdt.CountedAmount,
    cdt.DrawerAmount,
    cdt.TransactionCount,
    cd.Id AS CashDrawerId,
    cdt.OperatingPeriodCashDrawerId,
    -- Verify this matches
    CASE WHEN cd.Id = cdt.OperatingPeriodCashDrawerId THEN 'MATCH' ELSE 'NO MATCH' END AS JoinCheck
FROM {SWCCashDrawerTender} cdt
INNER JOIN {SWCCashDrawer} cd ON cdt.OperatingPeriodCashDrawerId = cd.Id
INNER JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
LEFT JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId AND cd.PosId = pt.PosId
LEFT JOIN {User} u ON cd.OperatorUserId = u.Id
WHERE cd.OperatingPeriodId = @PeriodId
  AND tt.TenderTypeId = 9  -- Offline Eftpos only
ORDER BY cd.PosId;
