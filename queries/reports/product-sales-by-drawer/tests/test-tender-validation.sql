-- =============================================
-- Test: Tender Type Validation
-- Purpose: Verify TenderType mappings and refund calculations are correct
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-28';

PRINT '=== TEST 1: All Tender Types Used ==='
-- Show all tender types being used in this period
SELECT DISTINCT
    tt.Id AS TenderTypeId,
    tt.Name AS TenderTypeName,
    tt.Category,
    CASE
        WHEN tt.Id = 0 THEN 'Cash'
        WHEN tt.Id IN (10, 13, 16, 19, 21) THEN 'Eftpos Group'
        WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN 'Gift Card/Coupon'
        ELSE 'Other'
    END AS MappedGroup
FROM {SWCPeriod} p
INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
INNER JOIN {SWCCashDrawerTender} cdt ON cd.Id = cdt.OperatingPeriodCashDrawerId
INNER JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
WHERE p.SiteId = @SiteId AND p.BusDate = @Date
ORDER BY tt.Id;

PRINT ''
PRINT '=== TEST 2: Refund Amounts by Tender Type ==='
-- Detail view of refunds per POS per tender type
SELECT
    cd.PosId,
    pt.Pod,
    tt.Id AS TenderTypeId,
    tt.Name AS TenderTypeName,
    cdt.RefundAmount,
    cdt.RefundCount,
    cdt.CountedAmount,
    CASE
        WHEN tt.Id = 0 THEN 'CashRefund'
        WHEN tt.Id IN (10, 13, 16, 19, 21) THEN 'EftposRefund'
        WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN 'GCSold'
        ELSE 'Other'
    END AS UsedFor
FROM {SWCPeriod} p
INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
INNER JOIN {SWCPosTerminal} pt ON cd.PosId = pt.PosId AND cd.OperatingPeriodId = pt.OperatingPeriodId
INNER JOIN {SWCCashDrawerTender} cdt ON cd.Id = cdt.OperatingPeriodCashDrawerId
INNER JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
WHERE p.SiteId = @SiteId AND p.BusDate = @Date
ORDER BY cd.PosId, tt.Id;

PRINT ''
PRINT '=== TEST 3: Aggregated Refunds Per POS ==='
-- Verify aggregation matches main query
SELECT
    cd.PosId,
    pt.Pod,
    SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END) AS CashRefund,
    SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END) AS EftposRefund,
    SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END) AS GCSold,
    COUNT(DISTINCT cdt.TenderTypeId) AS UniqueTenderTypes
FROM {SWCPeriod} p
INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
INNER JOIN {SWCPosTerminal} pt ON cd.PosId = pt.PosId AND cd.OperatingPeriodId = pt.OperatingPeriodId
LEFT JOIN {SWCCashDrawerTender} cdt ON cd.Id = cdt.OperatingPeriodCashDrawerId
LEFT JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
WHERE p.SiteId = @SiteId AND p.BusDate = @Date
GROUP BY cd.PosId, pt.Pod
ORDER BY cd.PosId;

PRINT ''
PRINT '=== TEST 4: Gift Card/Coupon Detail ==='
-- Show all gift card/coupon transactions
SELECT
    cd.PosId,
    pt.Pod,
    tt.Id AS TenderTypeId,
    tt.Name AS TenderTypeName,
    tt.Category,
    cdt.CountedAmount,
    cdt.RefundAmount,
    cdt.NetAmount
FROM {SWCPeriod} p
INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
INNER JOIN {SWCPosTerminal} pt ON cd.PosId = pt.PosId AND cd.OperatingPeriodId = pt.OperatingPeriodId
INNER JOIN {SWCCashDrawerTender} cdt ON cd.Id = cdt.OperatingPeriodCashDrawerId
INNER JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
WHERE p.SiteId = @SiteId
    AND p.BusDate = @Date
    AND tt.Category = 'TENDER_GIFT_COUPON'
ORDER BY cd.PosId;

PRINT ''
PRINT '=== TEST 5: Verify TenderType IDs Match Spec ==='
-- Confirm the TenderTypeIds match the user's requirements
SELECT
    'Cash (Should be 0)' AS Check,
    COUNT(*) AS RecordCount
FROM {SWCCashDrawerTender} cdt
INNER JOIN {SWCCashDrawer} cd ON cdt.OperatingPeriodCashDrawerId = cd.Id
INNER JOIN {SWCPeriod} p ON cd.OperatingPeriodId = p.Id
WHERE p.SiteId = @SiteId AND p.BusDate = @Date AND cdt.TenderTypeId = 0

UNION ALL

SELECT
    'Eftpos Group (Should be 10,13,16,19,21)' AS Check,
    COUNT(*) AS RecordCount
FROM {SWCCashDrawerTender} cdt
INNER JOIN {SWCCashDrawer} cd ON cdt.OperatingPeriodCashDrawerId = cd.Id
INNER JOIN {SWCPeriod} p ON cd.OperatingPeriodId = p.Id
WHERE p.SiteId = @SiteId AND p.BusDate = @Date AND cdt.TenderTypeId IN (10, 13, 16, 19, 21)

UNION ALL

SELECT
    'Gift Card/Coupon (Category = TENDER_GIFT_COUPON)' AS Check,
    COUNT(*) AS RecordCount
FROM {SWCCashDrawerTender} cdt
INNER JOIN {SWCCashDrawer} cd ON cdt.OperatingPeriodCashDrawerId = cd.Id
INNER JOIN {SWCPeriod} p ON cd.OperatingPeriodId = p.Id
INNER JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
WHERE p.SiteId = @SiteId AND p.BusDate = @Date AND tt.Category = 'TENDER_GIFT_COUPON';
