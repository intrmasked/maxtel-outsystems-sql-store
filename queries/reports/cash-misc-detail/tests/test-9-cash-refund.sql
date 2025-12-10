-- =============================================
-- Test: Cash Refund
-- Purpose: Verify CashRefund (IsCash = 1) from SWCCashDrawerTender
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';

-- Get Period ID
DECLARE @PeriodId BIGINT;
SELECT @PeriodId = Id FROM {SWCPeriod} WHERE SiteId = @SiteId AND BusDate = @Date;

-- CASH REFUND DATA: Show aggregated by drawer with verification stats
SELECT
    cd.PosId AS POS,
    pt.Pod,
    u.Name AS CashierName,
    SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundAmount ELSE 0 END) AS CashRefundAmount,
    SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundCount ELSE 0 END) AS CashRefundCount,
    CASE
        WHEN SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundCount ELSE 0 END) = 0 THEN NULL
        ELSE SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundAmount ELSE 0 END) /
             SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundCount ELSE 0 END)
    END AS Average_CashRefund,

    -- Verification columns
    SUM(SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundAmount ELSE 0 END)) OVER() AS Total_CashRefund_Amount,
    SUM(SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundCount ELSE 0 END)) OVER() AS Total_CashRefund_Count,
    MIN(SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundAmount ELSE 0 END)) OVER() AS Min_Amount,
    MAX(SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundAmount ELSE 0 END)) OVER() AS Max_Amount
FROM {SWCCashDrawer} cd
INNER JOIN {SWCPeriod} p ON cd.OperatingPeriodId = p.Id
INNER JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId AND cd.PosId = pt.PosId
LEFT JOIN {User} u ON cd.OperatorUserId = u.Id
LEFT JOIN {SWCCashDrawerTender} cdt ON cd.Id = cdt.OperatingPeriodCashDrawerId
LEFT JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
WHERE cd.OperatingPeriodId = @PeriodId
GROUP BY cd.PosId, pt.Pod, u.Name
ORDER BY cd.PosId;
