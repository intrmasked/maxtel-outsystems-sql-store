-- =============================================
-- Test: Compare Main Query Output with Expected Values
-- Purpose: Run main query and validate against known totals from screenshot
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-28';

PRINT '=== MAIN QUERY OUTPUT (should match production) ==='

-- Main Query with CTE for per-POS data
;WITH PerPosData AS (
SELECT
    cd.PosId AS POS,
    pt.Pod AS Type,
    cd.FinalGT AS [Close],
    cd.InitialGT AS [Open],
    (cd.FinalGT - cd.InitialGT) AS Difference,

    -- Refunds by Tender Type
    SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END) AS CashRefund,
    SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END) AS EftposRefund,

    -- Gift Card/Coupon Sold (using CountedAmount for TENDER_GIFT_COUPON category)
    SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END) AS GCSold,

    -- Gross Sales = Difference - CashRefund - EftposRefund - GCSold
    (
        (cd.FinalGT - cd.InitialGT)
        - SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END)
        - SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END)
        - SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END)
    ) AS GrossSales,

    -- GST from SalesFact (optimized single query)
    ISNULL(sf.TotalTax, 0) AS GST,

    -- Net Sales = Gross Sales - GST
    (
        (cd.FinalGT - cd.InitialGT)
        - SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END)
        - SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END)
        - SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END)
        - ISNULL(sf.TotalTax, 0)
    ) AS NetSales,

    -- Non-Product Sales from SalesFact (optimized single query)
    ISNULL(sf.NonProdSales, 0) AS NonProdSales,

    -- Product Sales from SalesFact (optimized single query)
    ISNULL(sf.ProdSales, 0) AS ProdSales

FROM {SWCPeriod} p

-- Join to Cash Drawer via Operating Period
INNER JOIN {SWCCashDrawer} cd
    ON p.Id = cd.OperatingPeriodId

-- Join to POS Terminal for Pod/Type
INNER JOIN {SWCPosTerminal} pt
    ON cd.PosId = pt.PosId
    AND cd.OperatingPeriodId = pt.OperatingPeriodId

-- Join to Cash Drawer Tenders for refund and GC data
LEFT JOIN {SWCCashDrawerTender} cdt
    ON cd.Id = cdt.OperatingPeriodCashDrawerId

-- Join to TenderType for Category (TENDER_GIFT_COUPON)
LEFT JOIN {TenderType} tt
    ON cdt.TenderTypeId = tt.Id

-- OPTIMIZED: Single SalesFact query for ALL sales data (GST, ProductSales, NonProdSales)
-- Reduces 3 separate database hits to 1
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
        AND ProductSaleTypeId IS NOT NULL  -- Include both product (1) and non-product (2)
        AND ProductMenuId IS NULL
        AND TenderTypeId IS NULL
        AND OperationId IS NULL
        AND OperationKindId IS NULL
        AND SWCCashDrawerId IS NULL
        AND SaleTypeId IS NULL
    GROUP BY PosId, Pod
) sf ON cd.PosId = sf.PosId AND pt.Pod = sf.Pod

WHERE
    -- Filter by site and date via SWCPeriod
    p.SiteId = @SiteId
    AND p.BusDate = @Date

GROUP BY
    cd.PosId,
    pt.Pod,
    cd.FinalGT,
    cd.InitialGT,
    sf.TotalTax,
    sf.ProdSales,
    sf.NonProdSales
)

-- Combine per-POS data with Total row
SELECT
    POS,
    Type,
    [Close],
    [Open],
    Difference,
    CashRefund,
    EftposRefund,
    GCSold,
    GrossSales,
    GST,
    NetSales,
    NonProdSales,
    ProdSales,
    CASE WHEN Type = 'Total' THEN 1 ELSE 0 END AS SortOrder
FROM PerPosData

UNION ALL

-- Total row: Sum all numeric columns
SELECT
    NULL AS POS,
    'Total' AS Type,
    NULL AS [Close],
    NULL AS [Open],
    SUM(Difference) AS Difference,
    SUM(CashRefund) AS CashRefund,
    SUM(EftposRefund) AS EftposRefund,
    SUM(GCSold) AS GCSold,
    SUM(GrossSales) AS GrossSales,
    SUM(GST) AS GST,
    SUM(NetSales) AS NetSales,
    SUM(NonProdSales) AS NonProdSales,
    SUM(ProdSales) AS ProdSales,
    1 AS SortOrder  -- Total row goes last
FROM PerPosData

ORDER BY
    SortOrder,  -- Total row (1) goes after POS rows (0)
    POS;

PRINT ''
PRINT '=== EXPECTED VALUES FROM SCREENSHOT (2025-08-30) ==='
PRINT 'Total Difference: 67,817.23'
PRINT 'Total CashRefund: 3.50'
PRINT 'Total GrossSales: 67,813.73'
PRINT 'Total GST: 8,844.62'
PRINT 'Total NetSales: 58,969.11'
PRINT 'Total NonProdSales: 46.87'
PRINT 'Total ProdSales: 58,922.24'
PRINT ''
PRINT 'NOTE: If testing with different date (2025-11-28), values will differ.'
PRINT 'Validate calculations are correct, not exact values.'
