-- =============================================
-- Test: Manager Meals Amount & Count
-- Purpose: Verify ManagerMealsAmount and ManagerMealsCount from SWCCashDrawer
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';

-- Get Period ID
DECLARE @PeriodId BIGINT;
SELECT @PeriodId = Id FROM {SWCPeriod} WHERE SiteId = @SiteId AND BusDate = @Date;

-- MANAGER MEALS DATA: Show manager meals amounts, counts, and verification stats
SELECT
    cd.PosId AS POS,
    pt.Pod,
    u.Name AS CashierName,
    cd.ManagerMealsAmount,
    cd.ManagerMealsCount,
    CASE
        WHEN cd.ManagerMealsCount = 0 THEN NULL
        ELSE cd.ManagerMealsAmount / cd.ManagerMealsCount
    END AS Average_ManagerMeal,

    -- Verification columns
    COUNT(*) OVER() AS Total_Rows,
    SUM(CASE WHEN cd.ManagerMealsAmount IS NOT NULL THEN 1 ELSE 0 END) OVER() AS Rows_With_Amount,
    SUM(CASE WHEN cd.ManagerMealsCount > 0 THEN 1 ELSE 0 END) OVER() AS Rows_With_Count,
    SUM(cd.ManagerMealsAmount) OVER() AS Total_ManagerMeals_Amount,
    SUM(cd.ManagerMealsCount) OVER() AS Total_ManagerMeals_Count,
    MIN(cd.ManagerMealsAmount) OVER() AS Min_Amount,
    MAX(cd.ManagerMealsAmount) OVER() AS Max_Amount
FROM {SWCCashDrawer} cd
INNER JOIN {SWCPeriod} p ON cd.OperatingPeriodId = p.Id
INNER JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId AND cd.PosId = pt.PosId
LEFT JOIN {User} u ON cd.OperatorUserId = u.Id
WHERE cd.OperatingPeriodId = @PeriodId
ORDER BY cd.PosId;
