-- =============================================
-- Test: Tender Data Diagnostic
-- Purpose: Verify tender data exists and check what TenderTypeIds we have
-- =============================================

DECLARE @SiteId BIGINT = 3187;
DECLARE @Date DATE = '2025-11-29';

-- Get Period ID
DECLARE @PeriodId BIGINT;
SELECT @PeriodId = Id FROM {SWCPeriod} WHERE SiteId = @SiteId AND BusDate = @Date;

-- Check 1: Show ALL tenders for this period (grouped by TenderTypeId)
SELECT
    'All Tenders for Period' AS CheckType,
    tt.TenderTypeId,
    tt.Name AS TenderTypeName,
    COUNT(DISTINCT cdt.OperatingPeriodCashDrawerId) AS DrawerCount,
    COUNT(*) AS TenderRecords,
    SUM(cdt.CountedAmount) AS Total_CountedAmount,
    SUM(cdt.DrawerAmount) AS Total_DrawerAmount,
    SUM(cdt.TransactionCount) AS Total_TransactionCount
FROM {SWCCashDrawerTender} cdt
INNER JOIN {SWCCashDrawer} cd ON cdt.OperatingPeriodCashDrawerId = cd.Id
INNER JOIN {TenderType} tt ON cdt.TenderTypeId = tt.Id
WHERE cd.OperatingPeriodId = @PeriodId
GROUP BY tt.TenderTypeId, tt.Name
ORDER BY tt.TenderTypeId;
