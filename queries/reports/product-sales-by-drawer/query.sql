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

    -- Sales (To be confirmed - currently set to 0)
    0 AS GrossSales,                     -- TODO: Confirm equation
    0 AS NetSales,                       -- TODO: Confirm equation

    -- GST from SalesFact
    ISNULL(sf.TotalTax, 0) AS GST,

    -- Non-Product and Product Sales
    0 AS NonProdSales,                   -- Field doesn't exist yet, blank for now
    (0 - 0) AS ProductSales              -- NetSales - NonProdSales (both 0 for now)

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

WHERE
    -- Filter by site and date via SWCPeriod
    p.SiteId = @SiteId
    AND p.BusDate = @Date

GROUP BY
    cd.PosId,
    pt.Pod,
    cd.FinalGT,
    cd.InitialGT,
    sf.TotalTax

ORDER BY
    cd.PosId;

-- =============================================
-- TODO / INCOMPLETE ITEMS:
-- 1. Confirm GrossSales equation (currently 0)
-- 2. Confirm NetSales equation (currently 0)
-- 3. ✅ TenderType.Category field verified (exists)
-- 4. ✅ SiteId and Date filter updated to use SWCPeriod
-- 5. ✅ SalesFact usage updated - joins via SWCPeriodId with proper filters
-- 6. Test GetPodFullName server action with Pod values
-- 7. Review and implement index recommendations
-- =============================================

-- =============================================
-- SALESFACT USAGE (Updated):
--
-- Approach:
--   - Join via: SWCPeriodId (OperatingPeriodId)
--   - Filters: SiteId, CalendarDate, DatePeriodDimensionId = 15
--   - Exclude: Empty PosId and Pod values
--   - Groups by: SWCPeriodId
--   - Aggregates: TaxAmount
--
-- This approach ensures:
--   - Proper period-level aggregation
--   - Filters out incomplete/invalid transactions
--   - DatePeriodDimensionId = 15 for specific dimension context
-- =============================================
