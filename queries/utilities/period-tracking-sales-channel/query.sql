-- =============================================
-- Query: PeriodTrackingSalesChannel
-- Purpose: Returns 3 Sales Channel rows for PeriodTrackingReport.SalesChannels,
--          aggregated over a date range:
--          1. MOP      - SWCPeriodTender where TenderType.Name = 'MOP'   (BusDate range)
--          2. Delivery - SWCPeriodTender where TenderType.IsDelivery = 1 (BusDate range)
--          3. McCafe   - SalesFact2 + ProductMenu + BO_MenuItem           (CalendarDate range)
-- Output:  Label, NetSales, Transactions, IsCalendarDay
-- Notes:
--   MOP/Delivery: CountedAmount (Gross), BusDate BETWEEN StartDate AND EndDate → IsCalendarDay = 0
--   McCafe:       NetAmount (Net), CalendarDate BETWEEN StartDate AND EndDate  → IsCalendarDay = 1
-- Target: SQL Server 2014+ / OutSystems Advanced SQL
-- Created: 2026-02-25
-- =============================================

/*
    OUTSYSTEMS PARAMETERS:
    - SiteId    (LongInteger) → Expand Inline = No
    - StartDate (Date)        → Expand Inline = No
    - EndDate   (Date)        → Expand Inline = No
*/

WITH

-- [STEP 1]: Get all Operating Periods for this site within the date range (BusDate)
-- Used by MOP and Delivery — they aggregate across all periods in the range
TargetPeriods AS (
    SELECT Id AS OperatingPeriodId
    FROM {SWCPeriod}
    WHERE SiteId = @SiteId
      AND BusDate BETWEEN @StartDate AND @EndDate
),

-- [STEP 2]: MOP Sales Channel (date range)
-- Source: SWCPeriodTender, TenderType.Name = 'MOP'
-- Amount: CountedAmount (Gross) summed across all periods in range
MOP_Data AS (
    SELECT
        ISNULL(SUM(spt.CountedAmount), 0)    AS NetSales,
        ISNULL(SUM(spt.TransactionCount), 0) AS Transactions
    FROM {SWCPeriodTender} spt
    INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
    INNER JOIN TargetPeriods tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
    WHERE tt.Name = 'MOP'
),

-- [STEP 3]: Delivery Sales Channel (date range)
-- Source: SWCPeriodTender, TenderType.IsDelivery = 1
-- Covers: MOP, DoorDash, UberEats, DeliverEasy
-- Amount: CountedAmount (Gross) summed across all periods in range
Delivery_Data AS (
    SELECT
        ISNULL(SUM(spt.CountedAmount), 0)    AS NetSales,
        ISNULL(SUM(spt.TransactionCount), 0) AS Transactions
    FROM {SWCPeriodTender} spt
    INNER JOIN {TenderType} tt ON spt.TenderTypeId = tt.Id
    INNER JOIN TargetPeriods tp ON spt.OperatingPeriodId = tp.OperatingPeriodId
    WHERE tt.IsDelivery = 1
),

-- [STEP 4]: McCafe Sales Channel (date range)
-- Source: SalesFact2 (Report_CS) joined via SWCPeriod + ProductMenu + BO_MenuItem
-- Amount: NetAmount (Net) summed across CalendarDate range
-- CRITICAL: All unused SalesFact dims must be NULL to prevent double-counting
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
    WHERE sp.SiteId = @SiteId
      AND sf2.CalendarDate BETWEEN @StartDate AND @EndDate
      AND sf2.DatePeriodDimensionId = 15
      AND mi.IsMcCafe = 1
      AND sf2.TenderTypeId IS NULL
      AND sf2.OperationId IS NULL
      AND sf2.OperationKindId IS NULL
      AND sf2.SWCCashDrawerId IS NULL
      AND sf2.SaleTypeId IS NULL
      AND sf2.ProductSaleTypeId = 1
      AND sf2.PosId IS NOT NULL
      AND sf2.PosId <> 0
)

-- [STEP 5]: Final Output - 3 rows, one per Sales Channel
-- IsCalendarDay: 0 = Business Date range (MOP/Delivery), 1 = Calendar Date range (McCafe)
SELECT 'MOP'      AS Label, m.NetSales, m.Transactions, CAST(0 AS BIT) AS IsCalendarDay FROM MOP_Data m
UNION ALL
SELECT 'Delivery' AS Label, d.NetSales, d.Transactions, CAST(0 AS BIT) AS IsCalendarDay FROM Delivery_Data d
UNION ALL
SELECT 'McCafe'   AS Label, mc.NetSales, mc.Transactions, CAST(1 AS BIT) AS IsCalendarDay FROM McCafe_Data mc;
