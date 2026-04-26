-- =============================================
-- Test: Find BusinessUserId for Abdul Haseeb
-- Purpose: Look up BusinessUserId via Person table to seed test favourites
-- =============================================

SELECT
    bu.Id AS BusinessUserId,
    bu.IsActive,
    bu.IsManager,
    bu.HomeSiteId,
    bu.PersonId
FROM {BusinessUser} bu
INNER JOIN {Person} p ON p.Id = bu.PersonId
WHERE p.Name LIKE '%Abdul%Haseeb%'
   OR p.Name LIKE '%Haseeb%'
