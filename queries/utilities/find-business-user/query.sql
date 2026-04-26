-- =============================================
-- Query: Find BusinessUserId
-- Purpose: Look up a BusinessUserId by person name
-- Usage: Change the LIKE filter to match the person you're looking for
-- Target: SQL Server 2014+
-- Created: 2026-04-26
-- =============================================

SELECT
    bu.Id AS BusinessUserId,
    bu.IsActive,
    bu.IsManager,
    bu.HomeSiteId,
    bu.PersonId
FROM {BusinessUser} bu
INNER JOIN {Person} p ON p.Id = bu.PersonId
WHERE p.Name LIKE '%Haseeb%'
