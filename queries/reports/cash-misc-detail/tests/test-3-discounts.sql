-- =============================================
-- Test: Discount Amount & Count
-- Purpose: Verify DiscountAmount and DiscountCount from SWCCashDrawer
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';

-- Get Period ID
DECLARE @PeriodId BIGINT;
SELECT @PeriodId = Id FROM {SWCPeriod} WHERE SiteId = @SiteId AND BusDate = @Date;

-- DISCOUNTS DATA: Show discount amounts, counts, and verification stats
SELECT
    cd.PosId AS POS,
    pt.Pod,
    u.Name AS CashierName,
    cd.DiscountAmount,
    cd.DiscountCount,
    CASE
        WHEN cd.DiscountCount = 0 THEN NULL
        ELSE cd.DiscountAmount / cd.DiscountCount
    END AS Average_Discount,

    -- Verification columns
    COUNT(*) OVER() AS Total_Rows,
    SUM(CASE WHEN cd.DiscountAmount IS NOT NULL THEN 1 ELSE 0 END) OVER() AS Rows_With_Amount,
    SUM(CASE WHEN cd.DiscountCount > 0 THEN 1 ELSE 0 END) OVER() AS Rows_With_Count,
    SUM(cd.DiscountAmount) OVER() AS Total_Discount_Amount,
    SUM(cd.DiscountCount) OVER() AS Total_Discount_Count,
    MIN(cd.DiscountAmount) OVER() AS Min_Amount,
    MAX(cd.DiscountAmount) OVER() AS Max_Amount
FROM {SWCCashDrawer} cd
INNER JOIN {SWCPeriod} p ON cd.OperatingPeriodId = p.Id
INNER JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId AND cd.PosId = pt.PosId
LEFT JOIN {User} u ON cd.OperatorUserId = u.Id
WHERE cd.OperatingPeriodId = @PeriodId
ORDER BY cd.PosId;
