-- =============================================
-- Test: Main Query Breakdown - Validate Each Component
-- Purpose: Break down main query to verify each calculation step by step
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-28';

-- Test 1: Cash Drawer GT Values (Difference calculation)
PRINT '=== TEST 1: Cash Drawer GT Values ==='
SELECT
    cd.PosId,
    pt.Pod,
    cd.InitialGT AS [Open],
    cd.FinalGT AS [Close],
    (cd.FinalGT - cd.InitialGT) AS Difference
FROM {SWCPeriod} p
INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
INNER JOIN {SWCPosTerminal} pt ON cd.PosId = pt.PosId AND cd.OperatingPeriodId = pt.OperatingPeriodId
WHERE p.SiteId = @SiteId AND p.BusDate = @Date
ORDER BY cd.PosId;

PRINT ''
PRINT '=== TEST 2: Refunds by Tender Type ==='
-- Test 2: Refunds breakdown
SELECT
    cd.PosId,
    pt.Pod,
    SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END) AS CashRefund,
    SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END) AS EftposRefund,
    SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END) AS GCSold
FROM {SWCPeriod} p
INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
INNER JOIN {SWCPosTerminal} pt ON cd.PosId = pt.PosId AND cd.OperatingPeriodId = pt.OperatingPeriodId
LEFT JOIN {SWCCashDrawerTender} cdt ON cd.Id = cdt.OperatingPeriodCashDrawerId
LEFT JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
WHERE p.SiteId = @SiteId AND p.BusDate = @Date
GROUP BY cd.PosId, pt.Pod
ORDER BY cd.PosId;

PRINT ''
PRINT '=== TEST 3: SalesFact Data Per POS ==='
-- Test 3: SalesFact breakdown
SELECT
    PosId,
    Pod,
    SUM(TaxAmount) AS TotalTax,
    SUM(CASE WHEN ProductSaleTypeId = 1 THEN NetAmount ELSE 0 END) AS ProdSales,
    SUM(CASE WHEN ProductSaleTypeId = 2 THEN NetAmount ELSE 0 END) AS NonProdSales,
    COUNT(*) AS RecordCount
FROM {SalesFact}
WHERE SiteId = @SiteId
    AND CalendarDate = @Date
    AND DatePeriodDimensionId = 15
    AND PosId <> ''
    AND Pod <> ''
    AND PosId IS NOT NULL
    AND ProductSaleTypeId IS NOT NULL
    AND ProductMenuId IS NULL
    AND TenderTypeId IS NULL
    AND OperationId IS NULL
    AND OperationKindId IS NULL
    AND SWCCashDrawerId IS NULL
    AND SaleTypeId IS NULL
GROUP BY PosId, Pod
ORDER BY PosId;

PRINT ''
PRINT '=== TEST 4: Full Calculation Match ==='
-- Test 4: Verify full calculation matches main query
SELECT
    cd.PosId AS POS,
    pt.Pod AS Type,
    cd.FinalGT AS [Close],
    cd.InitialGT AS [Open],
    (cd.FinalGT - cd.InitialGT) AS Difference,

    SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END) AS CashRefund,
    SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END) AS EftposRefund,
    SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END) AS GCSold,

    -- Gross Sales calculation step by step
    (cd.FinalGT - cd.InitialGT) AS Step1_Difference,
    SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END) AS Step2_CashRefund,
    SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END) AS Step3_EftposRefund,
    SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END) AS Step4_GCSold,

    (
        (cd.FinalGT - cd.InitialGT)
        - SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END)
        - SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END)
        - SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END)
    ) AS GrossSales,

    ISNULL(sf.TotalTax, 0) AS GST,

    (
        (cd.FinalGT - cd.InitialGT)
        - SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END)
        - SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END)
        - SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END)
        - ISNULL(sf.TotalTax, 0)
    ) AS NetSales,

    ISNULL(sf.NonProdSales, 0) AS NonProdSales,
    ISNULL(sf.ProdSales, 0) AS ProdSales

FROM {SWCPeriod} p
INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
INNER JOIN {SWCPosTerminal} pt ON cd.PosId = pt.PosId AND cd.OperatingPeriodId = pt.OperatingPeriodId
LEFT JOIN {SWCCashDrawerTender} cdt ON cd.Id = cdt.OperatingPeriodCashDrawerId
LEFT JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
LEFT JOIN (
    SELECT
        PosId,
        Pod,
        SUM(TaxAmount) AS TotalTax,
        SUM(CASE WHEN ProductSaleTypeId = 1 THEN NetAmount ELSE 0 END) AS ProdSales,
        SUM(CASE WHEN ProductSaleTypeId = 2 THEN NetAmount ELSE 0 END) AS NonProdSales
    FROM {SalesFact}
    WHERE SiteId = @SiteId
        AND CalendarDate = @Date
        AND DatePeriodDimensionId = 15
        AND PosId <> ''
        AND Pod <> ''
        AND PosId IS NOT NULL
        AND ProductSaleTypeId IS NOT NULL
        AND ProductMenuId IS NULL
        AND TenderTypeId IS NULL
        AND OperationId IS NULL
        AND OperationKindId IS NULL
        AND SWCCashDrawerId IS NULL
        AND SaleTypeId IS NULL
    GROUP BY PosId, Pod
) sf ON cd.PosId = sf.PosId AND pt.Pod = sf.Pod

WHERE p.SiteId = @SiteId AND p.BusDate = @Date

GROUP BY
    cd.PosId,
    pt.Pod,
    cd.FinalGT,
    cd.InitialGT,
    sf.TotalTax,
    sf.ProdSales,
    sf.NonProdSales

ORDER BY cd.PosId;

PRINT ''
PRINT '=== TEST 5: Totals Verification ==='
-- Test 5: Verify totals match sum of individual POS rows
SELECT
    'TOTALS' AS Label,
    SUM(Difference) AS TotalDifference,
    SUM(CashRefund) AS TotalCashRefund,
    SUM(EftposRefund) AS TotalEftposRefund,
    SUM(GCSold) AS TotalGCSold,
    SUM(GrossSales) AS TotalGrossSales,
    SUM(GST) AS TotalGST,
    SUM(NetSales) AS TotalNetSales,
    SUM(NonProdSales) AS TotalNonProdSales,
    SUM(ProdSales) AS TotalProdSales
FROM (
    SELECT
        cd.PosId AS POS,
        (cd.FinalGT - cd.InitialGT) AS Difference,
        SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END) AS CashRefund,
        SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END) AS EftposRefund,
        SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END) AS GCSold,
        (
            (cd.FinalGT - cd.InitialGT)
            - SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END)
            - SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END)
            - SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END)
        ) AS GrossSales,
        ISNULL(sf.TotalTax, 0) AS GST,
        (
            (cd.FinalGT - cd.InitialGT)
            - SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END)
            - SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END)
            - SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END)
            - ISNULL(sf.TotalTax, 0)
        ) AS NetSales,
        ISNULL(sf.NonProdSales, 0) AS NonProdSales,
        ISNULL(sf.ProdSales, 0) AS ProdSales
    FROM {SWCPeriod} p
    INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
    INNER JOIN {SWCPosTerminal} pt ON cd.PosId = pt.PosId AND cd.OperatingPeriodId = pt.OperatingPeriodId
    LEFT JOIN {SWCCashDrawerTender} cdt ON cd.Id = cdt.OperatingPeriodCashDrawerId
    LEFT JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
    LEFT JOIN (
        SELECT
            PosId,
            Pod,
            SUM(TaxAmount) AS TotalTax,
            SUM(CASE WHEN ProductSaleTypeId = 1 THEN NetAmount ELSE 0 END) AS ProdSales,
            SUM(CASE WHEN ProductSaleTypeId = 2 THEN NetAmount ELSE 0 END) AS NonProdSales
        FROM {SalesFact}
        WHERE SiteId = @SiteId
            AND CalendarDate = @Date
            AND DatePeriodDimensionId = 15
            AND PosId <> ''
            AND Pod <> ''
            AND PosId IS NOT NULL
            AND ProductSaleTypeId IS NOT NULL
            AND ProductMenuId IS NULL
            AND TenderTypeId IS NULL
            AND OperationId IS NULL
            AND OperationKindId IS NULL
            AND SWCCashDrawerId IS NULL
            AND SaleTypeId IS NULL
        GROUP BY PosId, Pod
    ) sf ON cd.PosId = sf.PosId AND pt.Pod = sf.Pod
    WHERE p.SiteId = @SiteId AND p.BusDate = @Date
    GROUP BY
        cd.PosId,
        pt.Pod,
        cd.FinalGT,
        cd.InitialGT,
        sf.TotalTax,
        sf.ProdSales,
        sf.NonProdSales
) AS AllRows;
