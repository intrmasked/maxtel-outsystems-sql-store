-- =============================================
-- Query: Product Sales By Drawer
-- Purpose: Cash drawer reconciliation report showing GT values, refunds, and sales by tender type
-- Target: SQL Server 2014+
-- Created: 2025-11-28
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 3187;           -- Site ID to filter (default test site)
DECLARE @Date DATE = '2025-11-28';       -- Date to filter (BusDate)

-- Main Query with CTE for per-POS data
;WITH PerPosData AS (
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
SELECT * FROM PerPosData

UNION ALL

-- Total row: Sum all numeric columns
SELECT
    'Total' AS POS,
    NULL AS Type,
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
    SUM(ProdSales) AS ProdSales
FROM PerPosData

ORDER BY
    CASE WHEN POS = 'Total' THEN 1 ELSE 0 END,  -- Total row goes last
    POS;

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
-- OPTIMIZATION NOTES:
--
-- Database Hit Reduction:
--   Previously: 3 separate SalesFact queries (sf, sfProd, sfNonProd)
--   Now: 1 single SalesFact query using CASE statements
--   Impact: 66% reduction in SalesFact table access
--
-- Total Row:
--   Added UNION ALL with aggregated totals
--   Total row shows 'Total' in POS column, sums for all numeric columns
--
-- =============================================
-- STATUS: IN TESTING - OPTIMIZED
-- Output: 13 columns matching OutSystems ProductSalesByDrawer structure
-- Includes Total row at bottom
-- =============================================
