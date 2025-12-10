-- =============================================
-- Test: Difference & Variance Calculation
-- Purpose: Verify Difference (FinalGT - InitialGT) and Variance from Period
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';

-- Get Period ID
DECLARE @PeriodId BIGINT;
SELECT @PeriodId = Id FROM {SWCPeriod} WHERE SiteId = @SiteId AND BusDate = @Date;

-- RAW DATA: Show drawer calculations and period variance
SELECT
    cd.PosId AS POS,
    pt.Pod,
    u.Name AS CashierName,
    cd.InitialGT,
    cd.FinalGT,
    (cd.FinalGT - cd.InitialGT) AS Calculated_Difference,
    p.TotalVariance AS Period_Variance,

    -- Verification columns
    COUNT(*) OVER() AS Total_Rows,
    MIN(cd.FinalGT - cd.InitialGT) OVER() AS Min_Difference,
    MAX(cd.FinalGT - cd.InitialGT) OVER() AS Max_Difference
FROM {SWCCashDrawer} cd
INNER JOIN {SWCPeriod} p ON cd.OperatingPeriodId = p.Id
INNER JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId AND cd.PosId = pt.PosId
LEFT JOIN {User} u ON cd.OperatorUserId = u.Id
WHERE cd.OperatingPeriodId = @PeriodId
ORDER BY cd.PosId;
