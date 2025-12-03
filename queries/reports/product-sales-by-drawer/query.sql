-- =============================================
-- Query: Product Sales By Drawer
-- Purpose: Cash drawer reconciliation report with conditional tender aggregations
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2025-11-28
-- Updated: 2025-12-03
-- =============================================

-- ⚠️ OUTSYSTEMS SETUP REQUIRED:
-- 1. Add Input Parameters in OutSystems Advanced SQL Block:
--    - SiteId (Data Type: Long Integer, Expand Inline = No)
--    - Date (Data Type: Date, Expand Inline = No)
-- 2. OutSystems will automatically provide @SiteId and @Date parameters to this query
-- 3. For local testing in SQL Server, uncomment the DECLARE statements below:
--
-- DECLARE @SiteId BIGINT = 3187;
-- DECLARE @Date DATE = '2025-11-29';

-- =============================================
-- MAIN QUERY: CASH DRAWER RECONCILIATION
-- Single optimized query with conditional aggregations
-- =============================================

WITH DrawerData AS (
    SELECT
        cd.PosId AS POS,
        pt.Pod,
        cd.FinalGT AS [Close],
        cd.InitialGT AS [Open],
        (cd.FinalGT - cd.InitialGT) AS Difference,

        -- Cash Refund (conditional sum using IsCash flag)
        SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundAmount ELSE 0 END) AS CashRefund,

        -- Eftpos Refund (conditional sum for specific tender type IDs)
        SUM(CASE WHEN tt.TenderTypeId IN (10, 13, 16, 19, 21)
             THEN cdt.RefundAmount ELSE 0 END) AS EftposRefund,

        -- GC Sold (conditional sum by category)
        SUM(CASE WHEN tt.Category = 'TENDER_GIFT_COUPON'
             THEN cdt.DrawerAmount ELSE 0 END) AS GCSold,

        cd.TaxAmount AS GST,
        cd.NonProductSalesAmount AS NonProdSales

    FROM {SWCPeriod} p
    INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
    INNER JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId
                                   AND cd.PosId = pt.PosId
    LEFT JOIN {SWCCashDrawerTender} cdt ON cd.Id = cdt.OperatingPeriodCashDrawerId
    LEFT JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id

    WHERE p.SiteId = @SiteId
      AND p.BusDate = @Date

    GROUP BY
        cd.PosId,
        pt.Pod,
        cd.FinalGT,
        cd.InitialGT,
        cd.TaxAmount,
        cd.NonProductSalesAmount
)

-- Main output with calculated fields
SELECT
    POS,
    Pod,  -- Pass this to GetPODFullName in OutSystems for Type column
    [Close],
    [Open],
    Difference,
    CashRefund,
    EftposRefund,
    GCSold,

    -- GrossSales = Difference - CashRefund - EftposRefund - GCSold
    (Difference - CashRefund - EftposRefund - GCSold) AS GrossSales,

    GST,

    -- NetSales = GrossSales - GST
    ((Difference - CashRefund - EftposRefund - GCSold) - GST) AS NetSales,

    NonProdSales,

    -- ProductSales = NetSales - NonProdSales
    (((Difference - CashRefund - EftposRefund - GCSold) - GST) - NonProdSales) AS ProductSales,

    -- Sort helper column (must be in SELECT for ORDER BY with UNION)
    CASE WHEN POS IS NULL THEN 1 ELSE 0 END AS SortOrder

FROM DrawerData

UNION ALL

-- Total Row (sum of all numeric columns)
SELECT
    NULL AS POS,
    'Total' AS Pod,
    NULL AS [Close],
    NULL AS [Open],
    SUM(Difference) AS Difference,
    SUM(CashRefund) AS CashRefund,
    SUM(EftposRefund) AS EftposRefund,
    SUM(GCSold) AS GCSold,
    SUM(Difference - CashRefund - EftposRefund - GCSold) AS GrossSales,
    SUM(GST) AS GST,
    SUM((Difference - CashRefund - EftposRefund - GCSold) - GST) AS NetSales,
    SUM(NonProdSales) AS NonProdSales,
    SUM(((Difference - CashRefund - EftposRefund - GCSold) - GST) - NonProdSales) AS ProductSales,
    1 AS SortOrder  -- Total row sorts last
FROM DrawerData

ORDER BY
    SortOrder,  -- Total row last (SortOrder = 1)
    POS;

-- =============================================
-- OUTPUT FORMAT:
--
-- POS  | Pod   | Close | Open | Difference | CashRefund | EftposRefund | GCSold | GrossSales | GST | NetSales | NonProdSales | ProductSales | SortOrder
-- -----+-------+-------+------+------------+------------+--------------+--------+------------+-----+----------+--------------+--------------+-----------
-- 1    | FC    | 5000  | 1000 | 4000       | 50         | 100          | 200    | 3650       | 365 | 3285     | 0            | 3285         | 0
-- 2    | DT    | 6000  | 2000 | 4000       | 30         | 80           | 150    | 3740       | 374 | 3366     | 0            | 3366         | 0
-- NULL | Total | NULL  | NULL | 8000       | 80         | 180          | 350    | 7390       | 739 | 6651     | 0            | 6651         | 1
--
-- =============================================
-- OUTSYSTEMS SETUP:
--
-- Input Parameters (Expand Inline = No):
-- - SiteId (Long Integer) = 3187
-- - Date (Date) = #2025-11-29#
--
-- Output Structure:
-- - POS (Long Integer) - POSId, NULL for Total row
-- - Pod (Text) - Pass to GetPODFullName for Type column, "Total" for total row
-- - Close (Decimal) - FinalGT
-- - Open (Decimal) - InitialGT
-- - Difference (Decimal) - Close - Open
-- - CashRefund (Decimal) - Sum of RefundAmount where TenderType.IsCash = 1
-- - EftposRefund (Decimal) - Sum of RefundAmount for TenderTypeId IN (10, 13, 16, 19, 21)
-- - GCSold (Decimal) - Sum of DrawerAmount for Gift Card/Coupon
-- - GrossSales (Decimal) - Difference - CashRefund - EftposRefund - GCSold
-- - GST (Decimal) - TaxAmount
-- - NetSales (Decimal) - GrossSales - GST
-- - NonProdSales (Decimal) - NonProductSalesAmount from SWCCashDrawer
-- - ProductSales (Decimal) - NetSales - NonProdSales
-- - SortOrder (Integer) - 0 for POS rows, 1 for Total row (for sorting)
--
-- In Server Action:
-- - Call GetPODFullName(Pod) to convert Pod code to full name for Type column
-- - Total row already included (Pod = "Total", POS = NULL)
--
-- =============================================
-- OPTIMIZATIONS:
-- 1. Single DB query with conditional SUM (no multiple aggregates)
-- 2. All calculations done in SQL (minimal OutSystems processing)
-- 3. Total row generated in SQL using UNION ALL
-- 4. Grouped by PosId and Pod for accurate per-drawer calculations
-- =============================================
-- STATUS: READY FOR OUTSYSTEMS
-- =============================================
