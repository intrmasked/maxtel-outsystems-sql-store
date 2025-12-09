-- =============================================
-- Query: Cash Misc - Detail Screen
-- Purpose: Cash drawer detail report with misc transactions by cashier
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2025-12-08
-- =============================================

-- ⚠️ OUTSYSTEMS SETUP REQUIRED:
-- 1. Add Input Parameters in OutSystems Advanced SQL Block:
--    - SiteId (Data Type: Long Integer, Expand Inline = No)
--    - Date (Data Type: Date, Expand Inline = No)
--    - SelectedView (Data Type: Text, Expand Inline = No)
-- 2. OutSystems will automatically provide @SiteId, @Date, and @SelectedView parameters
-- 3. For local testing in SQL Server, uncomment the DECLARE statements below:
--
-- DECLARE @SiteId BIGINT = 3187;
-- DECLARE @Date DATE = '2025-11-29';
-- DECLARE @SelectedView VARCHAR(1) = 'D';  -- 'D' = Dollars, 'G' = Guests, 'A' = Average

-- =============================================
-- MAIN QUERY: CASH MISC DETAIL
-- Shows one row per POS + Cashier with misc transactions
-- =============================================

WITH

-- [STEP 0]: Force Parameter Binding (Fixes OutSystems "Must declare variable" error)
InputVar AS (
    SELECT @SelectedView AS Val
),

-- [STEP 1]: Aggregate drawer data with conditional sums for tenders
DrawerData AS (
    SELECT
        cd.PosId AS POS,
        pt.Pod,
        cd.FinalGT,
        cd.InitialGT,
        p.TotalVariance AS Variance,

        -- Drawer amounts and counts
        cd.PromoAmount,
        cd.PromoCount,
        cd.DiscountAmount,
        cd.DiscountCount,
        cd.CrewMealsAmount,
        cd.CrewMealsCount,
        cd.ManagerMealsAmount,
        cd.ManagerMealsCount,
        cd.ReductionBeforeTotal,
        cd.ReductionAfterTotal,
        cd.ReductionCount,

        -- Conditional sums for tender types
        SUM(CASE WHEN cdt.TenderTypeId = 9 THEN cdt.DrawerAmount ELSE 0 END) AS OfflineEftposAmount,
        SUM(CASE WHEN cdt.TenderTypeId = 9 THEN cdt.TransactionCount ELSE 0 END) AS OfflineEftposCount,

        SUM(CASE WHEN cdt.TenderTypeId = 22 THEN cdt.DrawerAmount  ELSE 0 END) AS PettyCashAmount,
        SUM(CASE WHEN cdt.TenderTypeId = 22 THEN cdt.TransactionCount ELSE 0 END) AS PettyCashCount,

        SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundAmount ELSE 0 END) AS CashRefundAmount,
        SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundCount ELSE 0 END) AS CashRefundCount,

        SUM(CASE WHEN tt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END) AS EftposRefundAmount,
        SUM(CASE WHEN tt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundCount ELSE 0 END) AS EftposRefundCount,

        -- Cashier info
        cd.OperatorUserId,
        u.Name AS CashierName

    FROM {SWCPeriod} p
    INNER JOIN {SWCCashDrawer} cd ON p.Id = cd.OperatingPeriodId
    INNER JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId
                                   AND cd.PosId = pt.PosId
    LEFT JOIN {SWCCashDrawerTender} cdt ON cd.Id = cdt.OperatingPeriodCashDrawerId
    LEFT JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
    LEFT JOIN {User} u ON cd.OperatorUserId = u.Id

    WHERE p.SiteId = @SiteId
      AND p.BusDate = @Date

    GROUP BY
        cd.PosId,
        pt.Pod,
        cd.FinalGT,
        cd.InitialGT,
        p.TotalVariance,
        cd.PromoAmount,
        cd.PromoCount,
        cd.DiscountAmount,
        cd.DiscountCount,
        cd.CrewMealsAmount,
        cd.CrewMealsCount,
        cd.ManagerMealsAmount,
        cd.ManagerMealsCount,
        cd.ReductionBeforeTotal,
        cd.ReductionAfterTotal,
        cd.ReductionCount,
        cd.OperatorUserId,
        u.Name
)

-- [STEP 2]: Main output with view-based calculations
SELECT
    POS,
    Pod,  -- Pass this to GetPODFullName in OutSystems for Type column

    -- Difference and Variance (show as NULL for Guests view)
    CASE
        WHEN (SELECT Val FROM InputVar) = 'G' THEN NULL
        ELSE (FinalGT - InitialGT)
    END AS Difference,

    CASE
        WHEN (SELECT Val FROM InputVar) = 'G' THEN NULL
        ELSE Variance
    END AS Variance,

    -- Promo: Amount (D), Count (G), Average (A)
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN PromoAmount
        WHEN 'G' THEN CAST(PromoCount AS DECIMAL(18,2))
        WHEN 'A' THEN PromoAmount / NULLIF(PromoCount, 0)
        ELSE 0
    END AS Promo,

    -- Discounts: Amount (D), Count (G), Average (A)
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN DiscountAmount
        WHEN 'G' THEN CAST(DiscountCount AS DECIMAL(18,2))
        WHEN 'A' THEN DiscountAmount / NULLIF(DiscountCount, 0)
        ELSE 0
    END AS Discounts,

    -- Employee Meals: Amount (D), Count (G), Average (A)
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN CrewMealsAmount
        WHEN 'G' THEN CAST(CrewMealsCount AS DECIMAL(18,2))
        WHEN 'A' THEN CrewMealsAmount / NULLIF(CrewMealsCount, 0)
        ELSE 0
    END AS EmployeeMeals,

    -- Manager Meals: Amount (D), Count (G), Average (A)
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ManagerMealsAmount
        WHEN 'G' THEN CAST(ManagerMealsCount AS DECIMAL(18,2))
        WHEN 'A' THEN ManagerMealsAmount / NULLIF(ManagerMealsCount, 0)
        ELSE 0
    END AS ManagerMeals,

    -- Reduction Before Total: Amount (D), Count (G), Average (A)
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ReductionBeforeTotal
        WHEN 'G' THEN CAST(ReductionCount AS DECIMAL(18,2))
        WHEN 'A' THEN ReductionBeforeTotal / NULLIF(ReductionCount, 0)
        ELSE 0
    END AS ReductionBeforeTotal,

    -- Reduction After Total: Amount (D), Count (G), Average (A)
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ReductionAfterTotal
        WHEN 'G' THEN CAST(ReductionCount AS DECIMAL(18,2))
        WHEN 'A' THEN ReductionAfterTotal / NULLIF(ReductionCount, 0)
        ELSE 0
    END AS ReductionAfterTotal,

    -- Offline Eftpos: Amount (D), Count (G), Average (A)
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN OfflineEftposAmount
        WHEN 'G' THEN CAST(OfflineEftposCount AS DECIMAL(18,2))
        WHEN 'A' THEN OfflineEftposAmount / NULLIF(OfflineEftposCount, 0)
        ELSE 0
    END AS OfflineEftpos,

    -- Petty Cash: Amount (D), Count (G), Average (A)
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN PettyCashAmount
        WHEN 'G' THEN CAST(PettyCashCount AS DECIMAL(18,2))
        WHEN 'A' THEN PettyCashAmount / NULLIF(PettyCashCount, 0)
        ELSE 0
    END AS PettyCash,

    -- Cash Refund: Amount (D), Count (G), Average (A)
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN CashRefundAmount
        WHEN 'G' THEN CAST(CashRefundCount AS DECIMAL(18,2))
        WHEN 'A' THEN CashRefundAmount / NULLIF(CashRefundCount, 0)
        ELSE 0
    END AS CashRefund,

    -- Eftpos Refund: Amount (D), Count (G), Average (A)
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN EftposRefundAmount
        WHEN 'G' THEN CAST(EftposRefundCount AS DECIMAL(18,2))
        WHEN 'A' THEN EftposRefundAmount / NULLIF(EftposRefundCount, 0)
        ELSE 0
    END AS EftposRefund,

    CashierName AS Cashier,
    NULL AS Manager,  -- Leave blank per requirements

    -- Sort helper column
    0 AS SortOrder

FROM DrawerData

UNION ALL

-- [STEP 3]: Total row (sum all numeric columns)
SELECT
    NULL AS POS,
    'Total' AS Pod,

    -- Difference and Variance totals (NULL for Guests view)
    CASE
        WHEN (SELECT Val FROM InputVar) = 'G' THEN NULL
        ELSE SUM(FinalGT - InitialGT)
    END AS Difference,

    CASE
        WHEN (SELECT Val FROM InputVar) = 'G' THEN NULL
        ELSE SUM(Variance)
    END AS Variance,

    -- Promo total
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN SUM(PromoAmount)
        WHEN 'G' THEN SUM(CAST(PromoCount AS DECIMAL(18,2)))
        WHEN 'A' THEN SUM(PromoAmount) / NULLIF(SUM(PromoCount), 0)
        ELSE 0
    END AS Promo,

    -- Discounts total
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN SUM(DiscountAmount)
        WHEN 'G' THEN SUM(CAST(DiscountCount AS DECIMAL(18,2)))
        WHEN 'A' THEN SUM(DiscountAmount) / NULLIF(SUM(DiscountCount), 0)
        ELSE 0
    END AS Discounts,

    -- Employee Meals total
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN SUM(CrewMealsAmount)
        WHEN 'G' THEN SUM(CAST(CrewMealsCount AS DECIMAL(18,2)))
        WHEN 'A' THEN SUM(CrewMealsAmount) / NULLIF(SUM(CrewMealsCount), 0)
        ELSE 0
    END AS EmployeeMeals,

    -- Manager Meals total
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN SUM(ManagerMealsAmount)
        WHEN 'G' THEN SUM(CAST(ManagerMealsCount AS DECIMAL(18,2)))
        WHEN 'A' THEN SUM(ManagerMealsAmount) / NULLIF(SUM(ManagerMealsCount), 0)
        ELSE 0
    END AS ManagerMeals,

    -- Reduction Before Total
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN SUM(ReductionBeforeTotal)
        WHEN 'G' THEN SUM(CAST(ReductionCount AS DECIMAL(18,2)))
        WHEN 'A' THEN SUM(ReductionBeforeTotal) / NULLIF(SUM(ReductionCount), 0)
        ELSE 0
    END AS ReductionBeforeTotal,

    -- Reduction After Total
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN SUM(ReductionAfterTotal)
        WHEN 'G' THEN SUM(CAST(ReductionCount AS DECIMAL(18,2)))
        WHEN 'A' THEN SUM(ReductionAfterTotal) / NULLIF(SUM(ReductionCount), 0)
        ELSE 0
    END AS ReductionAfterTotal,

    -- Offline Eftpos total
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN SUM(OfflineEftposAmount)
        WHEN 'G' THEN SUM(CAST(OfflineEftposCount AS DECIMAL(18,2)))
        WHEN 'A' THEN SUM(OfflineEftposAmount) / NULLIF(SUM(OfflineEftposCount), 0)
        ELSE 0
    END AS OfflineEftpos,

    -- Petty Cash total
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN SUM(PettyCashAmount)
        WHEN 'G' THEN SUM(CAST(PettyCashCount AS DECIMAL(18,2)))
        WHEN 'A' THEN SUM(PettyCashAmount) / NULLIF(SUM(PettyCashCount), 0)
        ELSE 0
    END AS PettyCash,

    -- Cash Refund total
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN SUM(CashRefundAmount)
        WHEN 'G' THEN SUM(CAST(CashRefundCount AS DECIMAL(18,2)))
        WHEN 'A' THEN SUM(CashRefundAmount) / NULLIF(SUM(CashRefundCount), 0)
        ELSE 0
    END AS CashRefund,

    -- Eftpos Refund total
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN SUM(EftposRefundAmount)
        WHEN 'G' THEN SUM(CAST(EftposRefundCount AS DECIMAL(18,2)))
        WHEN 'A' THEN SUM(EftposRefundAmount) / NULLIF(SUM(EftposRefundCount), 0)
        ELSE 0
    END AS EftposRefund,

    NULL AS Cashier,
    NULL AS Manager,
    1 AS SortOrder  -- Total row sorts last

FROM DrawerData

ORDER BY
    SortOrder,  -- Total row last
    POS,
    Cashier;

-- =============================================
-- OUTPUT FORMAT:
--
-- POS  | Pod  | Difference | Variance | Promo | Discounts | EmployeeMeals | ManagerMeals | ReductionBeforeTotal | ReductionAfterTotal | OfflineEftpos | PettyCash | CashRefund | EftposRefund | Cashier | Manager
-- -----+------+------------+----------+-------+-----------+---------------+--------------+----------------------+---------------------+---------------+-----------+------------+--------------+---------+--------
-- 1    | FC   | 4000       | 1.80     | 97.17 | 65.34     | 97.27         | 80.42        | 119.15               | 34.63               | 0             | 0         | 0          | 0            | John    | NULL
-- 2    | DT   | 1720       | -0.30    | 106.7 | 40.98     | 82.12         | 104.78       | 122.79               | 35.69               | 0             | 3.50      | 0          | 0            | Jane    | NULL
-- NULL | Total| 5720       | 1.50     | 203.8 | 106.32    | 179.39        | 185.20       | 241.94               | 70.32               | 0             | 3.50      | 0          | 0            | NULL    | NULL
--
-- =============================================
-- OUTSYSTEMS SETUP:
--
-- Input Parameters (Expand Inline = No):
-- - SiteId (Long Integer) = 3187
-- - Date (Date) = #2025-11-29#
-- - SelectedView (Text) = "D" (Dollars), "G" (Guests), or "A" (Average)
--
-- Output Structure:
-- - POS (Long Integer) - POSId, NULL for Total row
-- - Pod (Text) - Pass to GetPODFullName for Type column
-- - Difference (Decimal) - FinalGT - InitialGT, NULL when SelectedView = 'G'
-- - Variance (Decimal) - TotalVariance, NULL when SelectedView = 'G'
-- - Promo (Decimal) - Amount/Count/Average based on SelectedView
-- - Discounts (Decimal) - Amount/Count/Average based on SelectedView
-- - EmployeeMeals (Decimal) - Crew meals Amount/Count/Average
-- - ManagerMeals (Decimal) - Amount/Count/Average based on SelectedView
-- - ReductionBeforeTotal (Decimal) - Amount/Count/Average based on SelectedView
-- - ReductionAfterTotal (Decimal) - Amount/Count/Average based on SelectedView
-- - OfflineEftpos (Decimal) - TenderTypeId = 9, Amount/Count/Average
-- - PettyCash (Decimal) - TenderTypeId = 22, Amount/Count/Average
-- - CashRefund (Decimal) - IsCash = 1, RefundAmount/RefundCount/Average
-- - EftposRefund (Decimal) - TenderTypeId IN (10,13,16,19,21), Amount/Count/Average
-- - Cashier (Text) - User.Name from OperatorUserId
-- - Manager (Text) - NULL (leave blank)
-- - SortOrder (Integer) - 0 for detail rows, 1 for Total row
--
-- View Filter Logic:
-- - 'D' (Dollars): Show Amount fields, show Difference and Variance
-- - 'G' (Guests): Show Count fields, hide Difference and Variance (NULL)
-- - 'A' (Average): Show Amount/Count calculations, show Difference and Variance
--
-- =============================================
-- OPTIMIZATIONS:
-- 1. Single DB query with conditional SUM for all tender types
-- 2. View-based calculations using CASE statements
-- 3. Total row generated in SQL using UNION ALL
-- 4. One row per POS + Cashier (OperatorUserId)
-- =============================================
-- STATUS: READY FOR OUTSYSTEMS
-- =============================================
