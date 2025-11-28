-- =============================================
-- Query: Product Sales By Drawer
-- Purpose: Cash drawer reconciliation report showing GT values, refunds, and sales by tender type
-- Target: SQL Server 2014+
-- Created: 2025-11-28
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 1;              -- Site ID to filter
DECLARE @Date DATE = '2025-11-28';       -- Date to filter (BusDate)

-- Main Query
SELECT
    cd.PosId AS POS,
    pt.Pod AS Type,                      -- Will be passed to GetPodFullName server action
    cd.FinalGT AS [Close],
    cd.InitialGT AS [Open],
    (cd.FinalGT - cd.InitialGT) AS Difference,
    0 AS Overring,                       -- Always 0 as per requirements

    -- Refunds by Tender Type
    SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END) AS CashRefund,
    SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END) AS EftposRefund,

    -- Gift Card/Coupon Sold (using CountedAmount for TENDER_GIFT_COUPON category)
    SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END) AS GCSold,

    -- Gross Sales = Difference - Overring - CashRefund - EftposRefund - OtherReceipt - GCSold
    (
        (cd.FinalGT - cd.InitialGT) - 0
        - SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END)
        - SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END)
        - 0  -- Other Receipt removed
        - SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END)
    ) AS GrossSales,

    -- GST from SalesFact
    ISNULL(sf.TotalTax, 0) AS GST,

    -- Net Sales = Gross Sales - GST
    (
        (cd.FinalGT - cd.InitialGT) - 0
        - SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END)
        - SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END)
        - 0
        - SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END)
        - ISNULL(sf.TotalTax, 0)
    ) AS NetSales,

    -- Non-Product Sales (ProductSaleTypeId = 2)
    ISNULL(sfNonProd.NonProdSales, 0) AS NonProdSales,

    -- Product Sales = Net Sales - Non-Product Sales
    (
        (cd.FinalGT - cd.InitialGT) - 0
        - SUM(CASE WHEN cdt.TenderTypeId = 0 THEN cdt.RefundAmount ELSE 0 END)
        - SUM(CASE WHEN cdt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END)
        - 0
        - SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END)
        - ISNULL(sf.TotalTax, 0)
        - ISNULL(sfNonProd.NonProdSales, 0)
    ) AS ProductSales

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

-- Aggregate SalesFact for GST
-- Join via OperatingPeriod (SWCPeriodId in SalesFact maps to SWCPeriod.Id)
LEFT JOIN (
    SELECT
        SWCPeriodId,
        SUM(TaxAmount) AS TotalTax
    FROM {SalesFact}
    WHERE SiteId = @SiteId
        AND CalendarDate = @Date
        AND DatePeriodDimensionId = 15
        AND PosId <> ''
        AND Pod <> ''
    GROUP BY SWCPeriodId
) sf ON p.Id = sf.SWCPeriodId

-- Aggregate SalesFact for Non-Product Sales (ProductSaleTypeId = 2)
LEFT JOIN (
    SELECT
        SWCPeriodId,
        SUM(NetAmount) AS NonProdSales
    FROM {SalesFact}
    WHERE SiteId = @SiteId
        AND CalendarDate = @Date
        AND DatePeriodDimensionId = 15
        AND PosId <> ''
        AND Pod <> ''
        AND ProductSaleTypeId = 2  -- Non-product sales
    GROUP BY SWCPeriodId
) sfNonProd ON p.Id = sfNonProd.SWCPeriodId

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
    sfNonProd.NonProdSales

ORDER BY
    cd.PosId;

-- =============================================
-- COMPLETE - All equations implemented:
-- 1. ✅ GrossSales = Difference - Overring - CashRefund - EftposRefund - OtherReceipt - GCSold
-- 2. ✅ NetSales = GrossSales - GST
-- 3. ✅ NonProdSales = SUM(NetAmount) WHERE ProductSaleTypeId = 2
-- 4. ✅ ProductSales = NetSales - NonProdSales
-- 5. ✅ TenderType.Category field verified (exists)
-- 6. ✅ SiteId and Date filter updated to use SWCPeriod
-- 7. ✅ SalesFact usage updated - joins via SWCPeriodId with proper filters
-- 8. Test GetPodFullName server action with Pod values
-- 9. Review and implement index recommendations
-- =============================================

-- =============================================
-- SALES CALCULATIONS:
--
-- Gross Sales Formula:
--   C - D - E - F - G - H where:
--   C = Difference (FinalGT - InitialGT)
--   D = Overring (always 0)
--   E = Cash Refund
--   F = EFTPOS Refund
--   G = Other Receipt (removed, = 0)
--   H = GC Sold
--
-- Net Sales:
--   Gross Sales - GST
--
-- Non-Product Sales:
--   SUM(NetAmount) from SalesFact WHERE ProductSaleTypeId = 2
--
-- Product Sales:
--   Net Sales - Non-Product Sales
-- =============================================
