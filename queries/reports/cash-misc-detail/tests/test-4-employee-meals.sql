-- =============================================
-- Test: Employee Meals (Crew Meals) Amount & Count
-- Purpose: Verify CrewMealsAmount and CrewMealsCount from SWCCashDrawer
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';

-- Get Period ID
DECLARE @PeriodId BIGINT;
SELECT @PeriodId = Id FROM {SWCPeriod} WHERE SiteId = @SiteId AND BusDate = @Date;

-- EMPLOYEE MEALS DATA: Show crew meals amounts, counts, and verification stats
SELECT
    cd.PosId AS POS,
    pt.Pod,
    u.Name AS CashierName,
    cd.CrewMealsAmount,
    cd.CrewMealsCount,
    CASE
        WHEN cd.CrewMealsCount = 0 THEN NULL
        ELSE cd.CrewMealsAmount / cd.CrewMealsCount
    END AS Average_CrewMeal,

    -- Verification columns
    COUNT(*) OVER() AS Total_Rows,
    SUM(CASE WHEN cd.CrewMealsAmount IS NOT NULL THEN 1 ELSE 0 END) OVER() AS Rows_With_Amount,
    SUM(CASE WHEN cd.CrewMealsCount > 0 THEN 1 ELSE 0 END) OVER() AS Rows_With_Count,
    SUM(cd.CrewMealsAmount) OVER() AS Total_CrewMeals_Amount,
    SUM(cd.CrewMealsCount) OVER() AS Total_CrewMeals_Count,
    MIN(cd.CrewMealsAmount) OVER() AS Min_Amount,
    MAX(cd.CrewMealsAmount) OVER() AS Max_Amount
FROM {SWCCashDrawer} cd
INNER JOIN {SWCPeriod} p ON cd.OperatingPeriodId = p.Id
INNER JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId AND cd.PosId = pt.PosId
LEFT JOIN {User} u ON cd.OperatorUserId = u.Id
WHERE cd.OperatingPeriodId = @PeriodId
ORDER BY cd.PosId;
