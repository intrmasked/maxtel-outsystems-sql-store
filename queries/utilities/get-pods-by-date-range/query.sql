-- =============================================
-- Query: Get Available PODs for Date Range
-- Purpose: Retrieve distinct PODs active in date range (lightning fast)
-- Target: SQL Server 2014+
-- Created: 2025-12-09
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';

-- Query: Get distinct PODs with sales activity in date range + Total row
WITH ActivePods AS (
    SELECT DISTINCT sf.Pod
    FROM {SalesFact} sf
    WHERE sf.SiteId = @SiteId
        AND sf.CalendarDate BETWEEN @StartDate AND @EndDate
        AND sf.DatePeriodDimensionId = 15
        AND sf.Pod IS NOT NULL AND sf.Pod <> ''
        AND sf.ProductSaleTypeId = 1
        AND sf.ProductMenuId IS NULL
        AND sf.TenderTypeId IS NULL
        AND sf.OperationId IS NULL
        AND sf.OperationKindId IS NULL
        AND sf.SWCCashDrawerId IS NULL
        AND sf.SaleTypeId IS NULL
),

PodList AS (
    SELECT
        'Total' AS podid,
        'Total' AS podname,
        0 AS SortOrder
    UNION ALL
    SELECT
        Pod AS podid,
        CASE Pod
            WHEN 'FC' THEN 'Counter'
            WHEN 'DT' THEN 'Drive-Thru'
            WHEN 'CSO' THEN 'Kiosk'
            WHEN 'DELIVERY' THEN 'Delivery'
            ELSE Pod
        END AS podname,
        ROW_NUMBER() OVER (ORDER BY Pod) AS SortOrder
    FROM ActivePods
)

-- Main output: POD ID + POD Name with sequential sort order
SELECT
    podid,
    podname,
    SortOrder
FROM PodList
ORDER BY SortOrder;
