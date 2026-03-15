-- =============================================
-- Query: ActualSales
-- Purpose: Returns quarter-hour actual + projected product sales
--          for all 96 trading slots (04:00→04:00) per Pod,
--          including zero-sales slots for DataHub consumption.
-- Output:  Pod, QtrHr, ProductSales, ProjectedProductSales
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2026-03-15
-- =============================================

/*
    OUTSYSTEMS PARAMETERS:
    - SiteId    (LongInteger) → Expand Inline = No
    - BusDate   (Date)        → Expand Inline = No
    - PodList   (Text)        → Expand Inline = Yes  (comma-separated Pod codes e.g. 'CO','DT')
    - BrandType (Text)        → Expand Inline = No
*/

WITH

-- Force OutSystems to recognise parameters early (Lazy Parser fix)
InputVar AS (
    SELECT @SiteId AS SiteId, @BusDate AS BusDate, @BrandType AS BrandType
),

-- [STEP 1]: Quarter-Hour Scaffold — 96 slots from 04:15 to next-day 04:00
--           Trading day = @BusDate 04:00  →  @BusDate+1 04:00
--           First QtrHr label = 04:15 (represents the 04:00-04:15 window)
QtrSlots AS (
    SELECT
        DATEADD(MINUTE, 15, CAST((SELECT BusDate FROM InputVar) AS DATETIME) + CAST('04:00' AS DATETIME)) AS QtrHr,
        DATEPART(HOUR, CAST((SELECT BusDate FROM InputVar) AS DATETIME) + CAST('04:00' AS DATETIME)) AS SlotHour,
        CAST((SELECT BusDate FROM InputVar) AS DATE) AS SlotDate
    UNION ALL
    SELECT
        DATEADD(MINUTE, 15, QtrHr),
        DATEPART(HOUR, QtrHr),
        CAST(QtrHr AS DATE)
    FROM QtrSlots
    WHERE QtrHr < DATEADD(MINUTE, -15, CAST(DATEADD(DAY, 1, (SELECT BusDate FROM InputVar)) AS DATETIME) + CAST('04:00' AS DATETIME))
),

-- [STEP 2]: Actual Sales — pre-aggregated from SalesFact
--           Single scan, filters match original query exactly
ActualSales AS (
    SELECT
        S.[POD],
        DATEADD(MINUTE, 15, S.[DateTime]) AS QtrHrDateTime,
        DATEPART(HOUR, S.[DateTime]) AS SalesHour,
        CAST(S.[DateTime] AS DATE) AS SalesDate,
        SUM(S.[NetAmount]) AS ProductSales
    FROM {SalesFact} S
    INNER JOIN {SWCPeriod} SP
        ON S.[SWCPeriodId] = SP.[Id]
    LEFT JOIN {ProductMenu} P
        ON S.[ProductMenuId] = P.[Id]
    LEFT JOIN {BO_MenuItem} B
        ON P.[ProductId] = B.[MIN]
        AND P.[ConceptId] = B.[ConceptId]
    WHERE SP.[SiteId] = (SELECT SiteId FROM InputVar)
      AND SP.[BusDate] = (SELECT BusDate FROM InputVar)
      AND ISNULL(S.[PosId], '') = ''
      AND S.[POD] IN (@PodList)
      AND B.[BrandType] = (SELECT BrandType FROM InputVar)
      AND ISNULL(S.[SalesFactTypeId], 0) = 2
      AND S.[DatePeriodDimensionId] = 15
      AND ISNULL(S.[OperationKindId], 0) = 0
      AND ISNULL(S.[SaleTypeId], 0) = 0
    GROUP BY
        S.[POD],
        DATEADD(MINUTE, 15, S.[DateTime]),
        DATEPART(HOUR, S.[DateTime]),
        CAST(S.[DateTime] AS DATE)
),

-- [STEP 3]: Active Pods — derived from ActualSales (no extra DB scan)
ActivePods AS (
    SELECT DISTINCT [POD] AS Pod FROM ActualSales
),

-- [STEP 4]: Full Scaffold — every QtrHr × every Pod
Scaffold AS (
    SELECT q.QtrHr, q.SlotHour, q.SlotDate, p.Pod
    FROM QtrSlots q
    CROSS JOIN ActivePods p
),

-- [STEP 5]: Hourly totals — for ProjectedProductSales ratio calc
--           Derived from ActualSales (no extra DB scan)
HourlyTotals AS (
    SELECT
        SalesHour,
        SalesDate,
        SUM(ProductSales) AS HourlyProductSales
    FROM ActualSales
    GROUP BY SalesHour, SalesDate
),

-- [STEP 6]: Merge Scaffold with Actuals + SalesHour projections
Merged AS (
    SELECT
        sc.Pod,
        sc.QtrHr,
        ISNULL(act.ProductSales, 0) AS ProductSales,
        sc.SlotHour,
        sc.SlotDate,
        ht.HourlyProductSales,
        sh.[ProjectedSalesExclGST]
    FROM Scaffold sc
    LEFT JOIN ActualSales act
        ON sc.Pod = act.[POD]
        AND sc.QtrHr = act.QtrHrDateTime
    LEFT JOIN HourlyTotals ht
        ON ht.SalesHour = sc.SlotHour
        AND ht.SalesDate = sc.SlotDate
    LEFT JOIN {SalesHour} sh
        ON sh.[SiteId] = (SELECT SiteId FROM InputVar)
        AND DATEPART(HOUR, sh.[StartDateTime]) = sc.SlotHour
        AND CAST(sh.[StartDateTime] AS DATE) = sc.SlotDate
)

-- [STEP 7]: Final Output
SELECT
    m.Pod,
    m.QtrHr,
    CAST(m.ProductSales AS DECIMAL(18,2)) AS ProductSales,
    CAST(
        ROUND(
            CASE
                WHEN ISNULL(m.HourlyProductSales, 0) = 0 THEN 0
                ELSE (ISNULL(m.ProjectedSalesExclGST, 0) / m.HourlyProductSales) * m.ProductSales
            END,
            2
        )
    AS DECIMAL(18,2)) AS ProjectedProductSales
FROM Merged m
ORDER BY m.Pod, m.QtrHr
OPTION (MAXRECURSION 100);
