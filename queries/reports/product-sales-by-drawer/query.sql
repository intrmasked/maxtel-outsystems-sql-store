-- =============================================
-- Query: Product Sales By Drawer
-- Purpose: Cash drawer reconciliation report showing GT values, refunds, and sales by tender type
-- Target: SQL Server 2014+
-- Created: 2025-11-28
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 3187;           -- Site ID to filter (default test site)
DECLARE @Date DATE = '2025-11-28';       -- Date to filter (BusDate)

-- Main Query
SELECT
    cd.PosId AS POS,
    pt.Pod AS Type,                      -- Will be passed to GetPodFullName server action
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

    -- GST from SalesFact
    ISNULL(sf.TotalTax, 0) AS GST,

    -- Net Sales = Gross Sales - GST
    (
        (cd.FinalGT - cd.InitialGT)
        - SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END)
        - SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END)
        - SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END)
        - ISNULL(sf.TotalTax, 0)
    ) AS NetSales,

    -- Non-Product Sales (ProductSaleTypeId = 2) from SalesFact
    ISNULL(sfNonProd.NonProdSales, 0) AS NonProdSales,

    -- Product Sales (ProductSaleTypeId = 1) from SalesFact
    ISNULL(sfProd.ProdSales, 0) AS ProdSales

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

-- Aggregate SalesFact for GST (ALL sales - product + non-product)
-- GROUP BY PosId and Pod to get per-POS-Pod GST
LEFT JOIN (
    SELECT
        PosId,
        Pod,
        SUM(TaxAmount) AS TotalTax
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

-- Aggregate SalesFact for Product Sales (ProductSaleTypeId = 1)
-- GROUP BY PosId and Pod to get per-POS-Pod Product Sales
LEFT JOIN (
    SELECT
        PosId,
        Pod,
        SUM(NetAmount) AS ProdSales
    FROM {SalesFact}
    WHERE SiteId = @SiteId
        AND CalendarDate = @Date
        AND DatePeriodDimensionId = 15
        AND PosId <> ''
        AND Pod <> ''
        AND PosId IS NOT NULL
        AND ProductSaleTypeId = 1  -- Product sales
        AND ProductSaleTypeId IS NOT NULL
        AND ProductMenuId IS NULL
        AND TenderTypeId IS NULL
        AND OperationId IS NULL
        AND OperationKindId IS NULL
        AND SWCCashDrawerId IS NULL
        AND SaleTypeId IS NULL
    GROUP BY PosId, Pod
) sfProd ON cd.PosId = sfProd.PosId AND pt.Pod = sfProd.Pod

-- Aggregate SalesFact for Non-Product Sales (ProductSaleTypeId = 2)
-- GROUP BY PosId and Pod to get per-POS-Pod Non-Product Sales
LEFT JOIN (
    SELECT
        PosId,
        Pod,
        SUM(NetAmount) AS NonProdSales
    FROM {SalesFact}
    WHERE SiteId = @SiteId
        AND CalendarDate = @Date
        AND DatePeriodDimensionId = 15
        AND PosId <> ''
        AND Pod <> ''
        AND PosId IS NOT NULL
        AND ProductSaleTypeId = 2  -- Non-product sales
        AND ProductSaleTypeId IS NOT NULL
        AND ProductMenuId IS NULL
        AND TenderTypeId IS NULL
        AND OperationId IS NULL
        AND OperationKindId IS NULL
        AND SWCCashDrawerId IS NULL
        AND SaleTypeId IS NULL
    GROUP BY PosId, Pod
) sfNonProd ON cd.PosId = sfNonProd.PosId AND pt.Pod = sfNonProd.Pod

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
    sfProd.ProdSales,
    sfNonProd.NonProdSales

ORDER BY
    cd.PosId;

-- =============================================
-- SALES CALCULATIONS:
--
-- Gross Sales Formula:
--   Difference - CashRefund - EftposRefund - GCSold
--   Where:
--     Difference = FinalGT - InitialGT
--     CashRefund = Refunds for TenderTypeId = 0
--     EftposRefund = Refunds for TenderTypeIds IN (10,13,16,19,21)
--     GCSold = Gift Card/Coupon sold
--
-- Net Sales:
--   GrossSales - GST
--
-- Product Sales (ProdSales):
--   SUM(NetAmount) from SalesFact WHERE ProductSaleTypeId = 1
--   Grouped by PosId, Pod for per-POS values
--
-- Non-Product Sales (NonProdSales):
--   SUM(NetAmount) from SalesFact WHERE ProductSaleTypeId = 2
--   Grouped by PosId, Pod for per-POS values
--
-- GST:
--   SUM(TaxAmount) from SalesFact (both product and non-product)
--   Grouped by PosId, Pod for per-POS values
--
-- =============================================
-- STATUS: IN TESTING
-- Output: 13 columns matching OutSystems ProductSalesByDrawer structure
-- =============================================
