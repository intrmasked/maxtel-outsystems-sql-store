-- =============================================
-- Test: Variance Breakdown by Tender
-- Purpose: Show variance calculation per tender type, then sum per drawer
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';

-- Get Period ID
DECLARE @PeriodId BIGINT;
SELECT @PeriodId = Id FROM {SWCPeriod} WHERE SiteId = @SiteId AND BusDate = @Date;

-- Show variance per tender type, grouped by drawer
SELECT
    cd.PosId AS POS,
    pt.Pod,
    u.Name AS CashierName,
    tt.Name AS TenderTypeName,
    cdt.ExpectedAmount,
    cdt.CountedAmount,
    (cdt.ExpectedAmount - cdt.CountedAmount) AS TenderVariance,

    -- Sum variance per drawer (all tenders for this drawer)
    SUM(cdt.ExpectedAmount - cdt.CountedAmount) OVER(PARTITION BY cd.PosId) AS DrawerTotalVariance,

    -- Verification: Count tenders per drawer
    COUNT(*) OVER(PARTITION BY cd.PosId) AS TendersForThisDrawer
FROM {SWCCashDrawerTender} cdt
INNER JOIN {SWCCashDrawer} cd ON cdt.OperatingPeriodCashDrawerId = cd.Id
INNER JOIN {SWCPeriod} p ON cd.OperatingPeriodId = p.Id
INNER JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId AND cd.PosId = pt.PosId
INNER JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
LEFT JOIN {User} u ON cd.OperatorUserId = u.Id
WHERE cd.OperatingPeriodId = @PeriodId
ORDER BY cd.PosId, tt.Name;
