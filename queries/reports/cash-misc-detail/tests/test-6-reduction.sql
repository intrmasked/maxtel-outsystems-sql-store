-- =============================================
-- Test: Reduction Before/After Total & Count
-- Purpose: Verify ReductionBeforeTotal, ReductionAfterTotal, and ReductionCount from SWCCashDrawer
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';

-- Get Period ID
DECLARE @PeriodId BIGINT;
SELECT @PeriodId = Id FROM {SWCPeriod} WHERE SiteId = @SiteId AND BusDate = @Date;

-- REDUCTION DATA: Show reduction before/after totals, counts, and verification stats
SELECT
    cd.PosId AS POS,
    pt.Pod,
    u.Name AS CashierName,
    cd.ReductionBeforeTotal,
    cd.ReductionAfterTotal,
    cd.ReductionCount,
    CASE
        WHEN cd.ReductionCount = 0 THEN NULL
        ELSE cd.ReductionBeforeTotal / cd.ReductionCount
    END AS Average_ReductionBefore,
    CASE
        WHEN cd.ReductionCount = 0 THEN NULL
        ELSE cd.ReductionAfterTotal / cd.ReductionCount
    END AS Average_ReductionAfter,

    -- Verification columns
    COUNT(*) OVER() AS Total_Rows,
    SUM(CASE WHEN cd.ReductionBeforeTotal IS NOT NULL THEN 1 ELSE 0 END) OVER() AS Rows_With_Before,
    SUM(CASE WHEN cd.ReductionAfterTotal IS NOT NULL THEN 1 ELSE 0 END) OVER() AS Rows_With_After,
    SUM(cd.ReductionBeforeTotal) OVER() AS Total_ReductionBefore,
    SUM(cd.ReductionAfterTotal) OVER() AS Total_ReductionAfter,
    SUM(cd.ReductionCount) OVER() AS Total_ReductionCount,
    MIN(cd.ReductionBeforeTotal) OVER() AS Min_Before,
    MAX(cd.ReductionBeforeTotal) OVER() AS Max_Before,
    MIN(cd.ReductionAfterTotal) OVER() AS Min_After,
    MAX(cd.ReductionAfterTotal) OVER() AS Max_After
FROM {SWCCashDrawer} cd
INNER JOIN {SWCPeriod} p ON cd.OperatingPeriodId = p.Id
INNER JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId AND cd.PosId = pt.PosId
LEFT JOIN {User} u ON cd.OperatorUserId = u.Id
WHERE cd.OperatingPeriodId = @PeriodId
ORDER BY cd.PosId;
