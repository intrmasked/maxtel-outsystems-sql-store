-- =============================================
-- Test: Eftpos Refund
-- Purpose: Verify EftposRefund (TenderTypeId IN 10, 13, 16, 19, 21) from SWCCashDrawerTender
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';

-- Get Period ID
DECLARE @PeriodId BIGINT;
SELECT @PeriodId = Id FROM {SWCPeriod} WHERE SiteId = @SiteId AND BusDate = @Date;

-- EFTPOS REFUND DATA: Show aggregated by drawer with verification stats
SELECT
    cd.PosId AS POS,
    pt.Pod,
    u.Name AS CashierName,
    SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END) AS EftposRefundAmount,
    SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundCount ELSE 0 END) AS EftposRefundCount,
    CASE
        WHEN SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundCount ELSE 0 END) = 0 THEN NULL
        ELSE SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END) /
             SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundCount ELSE 0 END)
    END AS Average_EftposRefund,

    -- Verification columns
    SUM(SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END)) OVER() AS Total_EftposRefund_Amount,
    SUM(SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundCount ELSE 0 END)) OVER() AS Total_EftposRefund_Count,
    MIN(SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END)) OVER() AS Min_Amount,
    MAX(SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END)) OVER() AS Max_Amount
FROM {SWCCashDrawer} cd
INNER JOIN {SWCPeriod} p ON cd.OperatingPeriodId = p.Id
INNER JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId AND cd.PosId = pt.PosId
LEFT JOIN {User} u ON cd.OperatorUserId = u.Id
LEFT JOIN {SWCCashDrawerTender} cdt ON cd.Id = cdt.OperatingPeriodCashDrawerId
WHERE cd.OperatingPeriodId = @PeriodId
GROUP BY cd.PosId, pt.Pod, u.Name
ORDER BY cd.PosId;
