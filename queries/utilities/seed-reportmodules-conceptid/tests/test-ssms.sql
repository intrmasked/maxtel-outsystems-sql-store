-- =============================================
-- Test: Seed ReportModules ConceptId
-- Purpose: Verify current state + run update + verify result
-- Target: SSMS (SQL Server 2016+)
-- Created: 2026-05-19
-- =============================================

DECLARE @ConceptId BIGINT = 129;

-- Check current state: how many rows need updating
SELECT
    rm.Id,
    rm.SupportedReportId,
    rm.MaxtelAppId,
    rm.ConceptId,
    COUNT(*) OVER() AS TotalRows,
    SUM(CASE WHEN rm.ConceptId IS NULL OR rm.ConceptId = 0 THEN 1 ELSE 0 END) OVER() AS RowsNeedingUpdate,
    SUM(CASE WHEN rm.ConceptId = @ConceptId THEN 1 ELSE 0 END) OVER() AS RowsAlreadySet
FROM {ReportModules} rm
