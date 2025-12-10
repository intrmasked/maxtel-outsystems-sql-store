-- =============================================
-- Test: Promo Amount & Count
-- Purpose: Verify PromoAmount and PromoCount from SWCCashDrawer
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';

-- Get Period ID
DECLARE @PeriodId BIGINT;
SELECT @PeriodId = Id FROM {SWCPeriod} WHERE SiteId = @SiteId AND BusDate = @Date;

-- PROMO DATA: Show promo amounts, counts, and verification stats
SELECT
    cd.PosId AS POS,
    pt.Pod,
    u.Name AS CashierName,
    cd.PromoAmount,
    cd.PromoCount,
    CASE
        WHEN cd.PromoCount = 0 THEN NULL
        ELSE cd.PromoAmount / cd.PromoCount
    END AS Average_Promo,

    -- Verification columns
    COUNT(*) OVER() AS Total_Rows,
    SUM(CASE WHEN cd.PromoAmount IS NOT NULL THEN 1 ELSE 0 END) OVER() AS Rows_With_Amount,
    SUM(CASE WHEN cd.PromoCount > 0 THEN 1 ELSE 0 END) OVER() AS Rows_With_Count,
    SUM(cd.PromoAmount) OVER() AS Total_Promo_Amount,
    SUM(cd.PromoCount) OVER() AS Total_Promo_Count,
    MIN(cd.PromoAmount) OVER() AS Min_Amount,
    MAX(cd.PromoAmount) OVER() AS Max_Amount
FROM {SWCCashDrawer} cd
INNER JOIN {SWCPeriod} p ON cd.OperatingPeriodId = p.Id
INNER JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId AND cd.PosId = pt.PosId
LEFT JOIN {User} u ON cd.OperatorUserId = u.Id
WHERE cd.OperatingPeriodId = @PeriodId
ORDER BY cd.PosId;
