-- =============================================
-- Query: Product Sales By Drawer
-- Purpose: Cash drawer reconciliation report showing GT values, refunds, and sales by tender type
-- Created: 2025-11-28
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 1;              -- Site ID to filter
DECLARE @Date DATE = '2025-11-28';       -- Date to filter

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
    -- Note: Requires join to TenderType table for Category field
    SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON' THEN cdt.CountedAmount ELSE 0 END) AS GCSold,

    -- Sales (To be confirmed - currently set to 0)
    0 AS GrossSales,                     -- TODO: Confirm equation
    0 AS NetSales,                       -- TODO: Confirm equation

    -- GST from SalesFact
    ISNULL(sf.TotalTax, 0) AS GST,

    -- Non-Product and Product Sales
    0 AS NonProdSales,                   -- Field doesn't exist yet, blank for now
    (0 - 0) AS ProductSales              -- NetSales - NonProdSales (both 0 for now)

FROM [dbo].[SWCCashDrawer] cd

-- Join to POS Terminal for Pod/Type
INNER JOIN [dbo].[SWCPosTerminal] pt
    ON cd.PosId = pt.PosId
    AND cd.OperatingPeriodId = pt.OperatingPeriodId

-- Join to Cash Drawer Tenders for refund and GC data
LEFT JOIN [dbo].[SWCCashDrawerTender] cdt
    ON cd.Id = cdt.OperatingPeriodCashDrawerId

-- Join to TenderType for Category (TENDER_GIFT_COUPON)
-- Note: Assuming TenderType table exists with Category field
LEFT JOIN [dbo].[TenderType] tt
    ON cdt.TenderTypeId = tt.Id

-- Aggregate SalesFact for GST
LEFT JOIN (
    SELECT
        SWCCashDrawerId,
        SUM(TaxAmount) AS TotalTax
    FROM [dbo].[SalesFact]
    WHERE CalendarDate = @Date
    GROUP BY SWCCashDrawerId
) sf ON cd.Id = sf.SWCCashDrawerId

WHERE
    -- Filter by date and site
    -- Note: Using LogOutDateTime as the session date identifier
    CAST(cd.LogOutDateTime AS DATE) = @Date
    -- If SiteId is needed, uncomment and add SiteId to SWCCashDrawer joins
    -- AND cd.SiteId = @SiteId

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
-- 3. Verify TenderType table exists and has Category field
-- 4. Confirm date filter field (using LogOutDateTime)
-- 5. Add SiteId filter if SWCCashDrawer has SiteId field
-- 6. Test GetPodFullName server action with Pod values
-- =============================================
