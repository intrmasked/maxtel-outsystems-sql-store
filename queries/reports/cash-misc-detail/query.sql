-- =============================================
-- Query: Cash Misc - Detail Screen
-- Purpose: Cash drawer detail report with misc transactions by cashier
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2025-12-08
-- Updated: 2025-12-10 - Performance optimization (pre-aggregation pattern)
-- =============================================

-- Parameters (for local SQL Server testing)
DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';
DECLARE @SelectedView VARCHAR(1) = 'D';  -- 'D' = Dollars, 'G' = Guests, 'A' = Average

WITH
-- [STEP 0]: Handle Parameters
InputVar AS (
    SELECT @SelectedView AS Val
),

-- [STEP 1]: Get the Scope (Period ID)
-- Small, fast Index Seek to get the single ID for this Date/Site
TargetPeriod AS (
    SELECT Id
    FROM {SWCPeriod}
    WHERE SiteId = @SiteId AND BusDate = @Date
),

-- [STEP 2]: Pre-Aggregate Tender Data (The "Child" Data)
-- We sum the tenders strictly by DrawerId. This produces 1 row per drawer.
-- This eliminates the need to Group By "PromoAmount", "CashierName", etc later.
TenderAgg AS (
    SELECT
        cdt.OperatingPeriodCashDrawerId,

        -- Offline Eftpos (Type 9)
        SUM(CASE WHEN tt.TenderTypeId = 9 THEN cdt.DrawerAmount ELSE 0 END) AS OfflineEftposAmount,
        SUM(CASE WHEN tt.TenderTypeId = 9 THEN cdt.TransactionCount ELSE 0 END) AS OfflineEftposCount,

        -- Petty Cash (Type 22)
        SUM(CASE WHEN tt.TenderTypeId = 22 THEN cdt.DrawerAmount  ELSE 0 END) AS PettyCashAmount,
        SUM(CASE WHEN tt.TenderTypeId = 22 THEN cdt.TransactionCount ELSE 0 END) AS PettyCashCount,

        -- Cash Refunds (IsCash = 1)
        SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundAmount ELSE 0 END) AS CashRefundAmount,
        SUM(CASE WHEN tt.IsCash = 1 THEN cdt.RefundCount ELSE 0 END) AS CashRefundCount,

        -- Eftpos Refunds (Eftpos, Doordash, MOP, Ubereats, Delivereasy)
        SUM(CASE WHEN tt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundAmount ELSE 0 END) AS EftposRefundAmount,
        SUM(CASE WHEN tt.TenderTypeId IN (10, 13, 16, 19, 21) THEN cdt.RefundCount ELSE 0 END) AS EftposRefundCount

    FROM {SWCCashDrawerTender} cdt
    INNER JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
    -- Direct join to filter drawers (faster than EXISTS)
    INNER JOIN (
        SELECT cd.Id
        FROM {SWCCashDrawer} cd
        INNER JOIN TargetPeriod tp ON cd.OperatingPeriodId = tp.Id
    ) drawer_filter ON cdt.OperatingPeriodCashDrawerId = drawer_filter.Id
    GROUP BY cdt.OperatingPeriodCashDrawerId
),

-- [STEP 3]: Fetch Drawer Data & Join Aggregates
-- No GROUP BY needed here because TenderAgg is already 1:1 with CashDrawer
CleanData AS (
    SELECT
        cd.PosId AS POS,
        CASE pt.Pod
            WHEN 'FC' THEN 'Counter'
            WHEN 'DT' THEN 'Drive-Thru'
            WHEN 'CSO' THEN 'Kiosk'
            WHEN 'DELIVERY' THEN 'Delivery'
            ELSE pt.Pod
        END AS Pod,
        u.Name AS CashierName,

        -- Drawer Level Data (No Summing needed, just select the columns)
        (cd.FinalGT - cd.InitialGT) AS Difference,
        p.TotalVariance AS Variance,

        cd.PromoAmount,       cd.PromoCount,
        cd.DiscountAmount,    cd.DiscountCount,
        cd.CrewMealsAmount,   cd.CrewMealsCount,
        cd.ManagerMealsAmount,cd.ManagerMealsCount,
        cd.ReductionBeforeTotal,
        cd.ReductionAfterTotal,
        cd.ReductionCount,

        -- Joined Tender Data (Handle NULLs if no matching tenders existed)
        ISNULL(t.OfflineEftposAmount, 0) AS OfflineEftposAmount,
        ISNULL(t.OfflineEftposCount, 0)  AS OfflineEftposCount,
        ISNULL(t.PettyCashAmount, 0)     AS PettyCashAmount,
        ISNULL(t.PettyCashCount, 0)      AS PettyCashCount,
        ISNULL(t.CashRefundAmount, 0)    AS CashRefundAmount,
        ISNULL(t.CashRefundCount, 0)     AS CashRefundCount,
        ISNULL(t.EftposRefundAmount, 0)  AS EftposRefundAmount,
        ISNULL(t.EftposRefundCount, 0)   AS EftposRefundCount

    FROM {SWCCashDrawer} cd
    INNER JOIN TargetPeriod tp ON cd.OperatingPeriodId = tp.Id
    INNER JOIN {SWCPeriod} p ON tp.Id = p.Id
    INNER JOIN {SWCPosTerminal} pt ON cd.OperatingPeriodId = pt.OperatingPeriodId AND cd.PosId = pt.PosId
    LEFT JOIN {User} u ON cd.OperatorUserId = u.Id
    LEFT JOIN TenderAgg t ON cd.Id = t.OperatingPeriodCashDrawerId
),

-- [STEP 4]: Create Total Row using UNION ALL
-- We prepare the raw data + a total line in one set
FinalCalculations AS (
    SELECT
        POS, Pod, CashierName,
        Difference, Variance,
        PromoAmount, PromoCount,
        DiscountAmount, DiscountCount,
        CrewMealsAmount, CrewMealsCount,
        ManagerMealsAmount, ManagerMealsCount,
        ReductionBeforeTotal, ReductionAfterTotal, ReductionCount,
        OfflineEftposAmount, OfflineEftposCount,
        PettyCashAmount, PettyCashCount,
        CashRefundAmount, CashRefundCount,
        EftposRefundAmount, EftposRefundCount
    FROM CleanData

    UNION ALL

    -- Total Row (Aggregated from the clean, small CleanData set)
    SELECT
        NULL, 'Total', NULL,
        SUM(Difference), SUM(Variance),
        SUM(PromoAmount), SUM(PromoCount),
        SUM(DiscountAmount), SUM(DiscountCount),
        SUM(CrewMealsAmount), SUM(CrewMealsCount),
        SUM(ManagerMealsAmount), SUM(ManagerMealsCount),
        SUM(ReductionBeforeTotal), SUM(ReductionAfterTotal), SUM(ReductionCount),
        SUM(OfflineEftposAmount), SUM(OfflineEftposCount),
        SUM(PettyCashAmount), SUM(PettyCashCount),
        SUM(CashRefundAmount), SUM(CashRefundCount),
        SUM(EftposRefundAmount), SUM(EftposRefundCount)
    FROM CleanData
)

-- [STEP 5]: Final Output & Display Logic
SELECT
    POS,
    Pod,

    -- Difference/Variance
    CASE WHEN (SELECT Val FROM InputVar) = 'G' THEN NULL ELSE Difference END AS Difference,
    CASE WHEN (SELECT Val FROM InputVar) = 'G' THEN NULL ELSE Variance END AS Variance,

    -- Promo
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN PromoAmount
        WHEN 'G' THEN CAST(PromoCount AS DECIMAL(18,2))
        WHEN 'A' THEN PromoAmount / NULLIF(PromoCount, 0) ELSE 0 END AS Promo,

    -- Discounts
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN DiscountAmount
        WHEN 'G' THEN CAST(DiscountCount AS DECIMAL(18,2))
        WHEN 'A' THEN DiscountAmount / NULLIF(DiscountCount, 0) ELSE 0 END AS Discounts,

    -- Employee Meals
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN CrewMealsAmount
        WHEN 'G' THEN CAST(CrewMealsCount AS DECIMAL(18,2))
        WHEN 'A' THEN CrewMealsAmount / NULLIF(CrewMealsCount, 0) ELSE 0 END AS EmployeeMeals,

    -- Manager Meals
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ManagerMealsAmount
        WHEN 'G' THEN CAST(ManagerMealsCount AS DECIMAL(18,2))
        WHEN 'A' THEN ManagerMealsAmount / NULLIF(ManagerMealsCount, 0) ELSE 0 END AS ManagerMeals,

    -- Reduction Before
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ReductionBeforeTotal
        WHEN 'G' THEN CAST(ReductionCount AS DECIMAL(18,2))
        WHEN 'A' THEN ReductionBeforeTotal / NULLIF(ReductionCount, 0) ELSE 0 END AS ReductionBeforeTotal,

    -- Reduction After
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN ReductionAfterTotal
        WHEN 'G' THEN CAST(ReductionCount AS DECIMAL(18,2))
        WHEN 'A' THEN ReductionAfterTotal / NULLIF(ReductionCount, 0) ELSE 0 END AS ReductionAfterTotal,

    -- Offline Eftpos
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN OfflineEftposAmount
        WHEN 'G' THEN CAST(OfflineEftposCount AS DECIMAL(18,2))
        WHEN 'A' THEN OfflineEftposAmount / NULLIF(OfflineEftposCount, 0) ELSE 0 END AS OfflineEftpos,

    -- Petty Cash
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN PettyCashAmount
        WHEN 'G' THEN CAST(PettyCashCount AS DECIMAL(18,2))
        WHEN 'A' THEN PettyCashAmount / NULLIF(PettyCashCount, 0) ELSE 0 END AS PettyCash,

    -- Cash Refund
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN CashRefundAmount
        WHEN 'G' THEN CAST(CashRefundCount AS DECIMAL(18,2))
        WHEN 'A' THEN CashRefundAmount / NULLIF(CashRefundCount, 0) ELSE 0 END AS CashRefund,

    -- Eftpos Refund
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN EftposRefundAmount
        WHEN 'G' THEN CAST(EftposRefundCount AS DECIMAL(18,2))
        WHEN 'A' THEN EftposRefundAmount / NULLIF(EftposRefundCount, 0) ELSE 0 END AS EftposRefund,

    CashierName AS Cashier,
    NULL AS Manager

FROM FinalCalculations
ORDER BY
    CASE WHEN Pod = 'Total' THEN 1 ELSE 0 END,  -- Total row last
    POS,
    Cashier
OPTION (RECOMPILE);
