/*
   ===================================================================================
   TEST QUERY: GET AVAILABLE PODS FOR DATE RANGE - SSMS VERSION
   ===================================================================================
   
   SSMS-compatible version using STRING_SPLIT for comma-separated @SiteIds.
   Production query uses OutSystems Expand Inline = YES.
   
   ===================================================================================
*/

DECLARE @SiteIds NVARCHAR(MAX) = '3187';
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';

WITH ActivePods AS (
    SELECT DISTINCT sf.Pod
    FROM {SalesFact} sf
    WHERE sf.SiteId IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
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

SELECT podid, podname, SortOrder
FROM PodList
ORDER BY SortOrder;
