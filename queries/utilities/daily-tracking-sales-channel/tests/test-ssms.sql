-- =============================================
-- Test: SSMS Version - DailyTrackingSalesChannel
-- Purpose: Full query with DECLARE params for testing in SSMS / SQL Sandbox
-- Run in: SQL Sandbox (SSMS format)
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-12-04';

WITH
TargetPeriod AS (
    SELECT Id AS OperatingPeriodId
    FROM {SWCPeriod}
    WHERE SiteId = @SiteId
      AND BusDate = @Date
),
MOP_Data AS (
    SELECT
        ISNULL(SUM(spt.CountedAmount), 0)    AS NetSales,
        ISNULL(SUM(spt.TransactionCount), 0) AS Transactions
    FROM {SWCPeriodTender} spt
    INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
    INNER JOIN TargetPeriod tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
    WHERE tt.Name = 'MOP'
),
Delivery_Data AS (
    SELECT
        ISNULL(SUM(spt.CountedAmount), 0)    AS NetSales,
        ISNULL(SUM(spt.TransactionCount), 0) AS Transactions
    FROM {SWCPeriodTender} spt
    INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
    INNER JOIN TargetPeriod tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
    WHERE tt.IsDelivery = 1
),
McCafe_Data AS (
    SELECT
        ISNULL(SUM(sf2.NetAmount), 0)        AS NetSales,
        ISNULL(SUM(sf2.TransactionCount), 0) AS Transactions
    FROM {SalesFact} sf2
    INNER JOIN {SWCPeriod} sp  ON sf2.SWCPeriodId  = sp.Id
    LEFT JOIN  {ProductMenu} pm ON sf2.ProductMenuId = pm.Id
    LEFT JOIN  {BO_MenuItem} mi ON pm.ProductId      = mi.MIN
                                AND pm.ConceptId      = mi.ConceptId
                                AND mi.IsMcCafe       = 1
    WHERE sp.SiteId = @SiteId
      AND sp.BusDate = @Date
      AND ISNULL(sf2.PosId, '')          = ''
      AND ISNULL(sf2.SalesFactTypeId, 0) = 2
      AND sf2.DatePeriodDimensionId      = 15
      AND ISNULL(sf2.OperationKindId, 0) = 0
      AND ISNULL(sf2.SaleTypeId, 0)      = 0
      AND mi.IsMcCafe                    = 1
)

SELECT 'MOP'      AS Label, m.NetSales, m.Transactions, CAST(0 AS BIT) AS IsCalendarDay FROM MOP_Data m
UNION ALL
SELECT 'Delivery' AS Label, d.NetSales, d.Transactions, CAST(0 AS BIT) AS IsCalendarDay FROM Delivery_Data d
UNION ALL
SELECT 'McCafe'   AS Label, mc.NetSales, mc.Transactions, CAST(1 AS BIT) AS IsCalendarDay FROM McCafe_Data mc
