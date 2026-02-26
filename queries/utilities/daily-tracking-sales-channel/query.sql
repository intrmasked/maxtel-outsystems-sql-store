-- =============================================
-- Query: DailyTrackingSalesChannel
-- Purpose: Returns 3 Sales Channel rows for DailyTrackingReport.SalesChannels:
--          1. MOP      - SWCPeriodTender where TenderType.Name = 'MOP'   (BusDate)
--          2. Delivery - SWCPeriodTender where TenderType.IsDelivery = 1 (BusDate)
--          3. McCafe   - SalesFact2 + ProductMenu + BO_MenuItem (BusDate via SWCPeriod)
-- Output:  Label, NetSales, Transactions, IsCalendarDay
-- Notes:
--   MOP/Delivery: CountedAmount (Gross), BusDate via SWCPeriod → IsCalendarDay = 0
--   McCafe:       NetAmount (Net), BusDate via SWCPeriod → IsCalendarDay = 1
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2026-02-24
-- =============================================

/*
    OUTSYSTEMS PARAMETERS:
    - SiteId (LongInteger) → Expand Inline = No
    - Date   (Date)        → Expand Inline = No
*/

WITH

-- [STEP 1]: Get the Operating Period for this site/date (BusDate)
-- Used by MOP and Delivery — they filter by Business Date
TargetPeriod AS (
    SELECT Id AS OperatingPeriodId
    FROM {SWCPeriod}
    WHERE SiteId = @SiteId
      AND BusDate = @Date
),

-- [STEP 2]: MOP Sales Channel
-- Source: SWCPeriodTender, TenderType.Name = 'MOP'
-- Amount: CountedAmount (Gross) — agreed, no tax
-- Date type: Business Date → IsCalendarDay = 0
MOP_Data AS (
    SELECT
        ISNULL(SUM(spt.CountedAmount), 0)    AS NetSales,
        ISNULL(SUM(spt.TransactionCount), 0) AS Transactions
    FROM {SWCPeriodTender} spt
    INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
    INNER JOIN TargetPeriod tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
    WHERE tt.Name = 'MOP'
),

-- [STEP 3]: Delivery Sales Channel
-- Source: SWCPeriodTender, TenderType.IsDelivery = 1
-- Amount: CountedAmount (Gross) — agreed, no tax
-- Date type: Business Date → IsCalendarDay = 0
Delivery_Data AS (
    SELECT
        ISNULL(SUM(spt.CountedAmount), 0)    AS NetSales,
        ISNULL(SUM(spt.TransactionCount), 0) AS Transactions
    FROM {SWCPeriodTender} spt
    INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
    INNER JOIN TargetPeriod tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
    WHERE tt.IsDelivery = 1
),

-- [STEP 4]: McCafe Sales Channel
-- Source: SalesFact (sf2) joined via SWCPeriod, then LEFT JOIN ProductMenu + BO_MenuItem
-- ConceptId matched naturally via ProductMenu — no input param needed
-- Amount: NetAmount (Net)
-- Date type: BusDate via SWCPeriod → IsCalendarDay = 1
-- Filters: SalesFactTypeId=2, PosId='', OperationKindId=0, SaleTypeId=0, DatePeriodDimensionId=15
McCafe_Data AS (
    SELECT
        ISNULL(SUM(sf2.NetAmount), 0)        AS NetSales,
        ISNULL(SUM(sf2.TransactionCount), 0) AS Transactions
    FROM {SalesFact2} sf2  -- NOTE: {SalesFact2} used here (not {SalesFact}) because this query runs
                           -- in the Report_CS module context where SalesFact is exposed as SalesFact2.
                           -- This is a one-off — all other queries in this store use {SalesFact}.
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

-- [STEP 5]: Final Output - 3 rows, one per Sales Channel
-- IsCalendarDay: 0 = Business Date (MOP/Delivery), 1 = Calendar Date (McCafe)
SELECT 'MOP'      AS Label, m.NetSales, m.Transactions, CAST(0 AS BIT) AS IsCalendarDay FROM MOP_Data m
UNION ALL
SELECT 'Delivery' AS Label, d.NetSales, d.Transactions, CAST(0 AS BIT) AS IsCalendarDay FROM Delivery_Data d
UNION ALL
SELECT 'McCafe'   AS Label, mc.NetSales, mc.Transactions, CAST(1 AS BIT) AS IsCalendarDay FROM McCafe_Data mc;
