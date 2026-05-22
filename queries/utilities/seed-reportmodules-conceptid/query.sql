-- =============================================
-- Query: Seed ReportModules ConceptId
-- Purpose: Assign ConceptId 129 to all existing ReportModules rows
--          after adding the ConceptId column to the table.
-- Target: SQL Server 2014+
-- Created: 2026-05-19
-- Story: #3824
-- =============================================

UPDATE {ReportModules}
SET ConceptId = 129
WHERE ConceptId IS NULL
   OR ConceptId = 0
