-- =============================================
-- Test: Difference & Variance Calculation
-- Purpose: Verify Difference (FinalGT - InitialGT) and Variance (sum from tenders)
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';

-- Get Period ID
DECLARE @PeriodId BIGINT;
SELECT @PeriodId = Id FROM {SWCPeriod} WHERE SiteId = @SiteId AND BusDate = @Date;

-- Show drawer calculations with tender-based variance
WITH TenderVariance AS (
    SELECT
        cdt.OperatingPeriodCashDrawerId,
        SUM(cdt.ExpectedAmount - cdt.CountedAmount) AS TotalVariance
    FROM {SWCCashDrawerTender} cdt
    INNER JOIN {SWCCashDrawer} cd ON cdt.OperatingPeriodCashDrawerId = cd.Id
    WHERE cd.OperatingPeriodId = @PeriodId
    GROUP BY cdt.OperatingPeriodCashDrawerId
)
SELECT
    cd.PosId AS POS,
    pt.Pod,
    u.Name AS CashierName,
    cd.InitialGT,
    cd.FinalGT,
    (cd.FinalGT - cd.InitialGT) AS Calculated_Difference,
    ISNULL(tv.TotalVariance, 0) AS Calculated_Variance,

    -- Verification columns
    COUNT(*) OVER() AS Total_Rows,
    MIN(cd.FinalGT - cd.InitialGT) OVER() AS Min_Difference,
    MAX(cd.FinalGT - cd.InitialGT) OVER() AS Max_Difference,
    MIN(ISNULL(tv.TotalVariance, 0)) OVER() AS Min_Variance,
    MAX(ISNULL(tv.TotalVariance, 0)) OVER() AS Max_Variance
FROM {SWCCashDrawer} cd
INNER JOIN {SWCPeriod} p ON cd.OperatingPeriodId = p.Id
INNER JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId AND cd.PosId = pt.PosId
LEFT JOIN {User} u ON cd.OperatorUserId = u.Id
LEFT JOIN TenderVariance tv ON cd.Id = tv.OperatingPeriodCashDrawerId
WHERE cd.OperatingPeriodId = @PeriodId
ORDER BY cd.PosId;
