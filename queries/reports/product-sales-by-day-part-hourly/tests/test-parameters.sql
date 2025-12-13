/*
   ===================================================================================
   TEST QUERY: Parameter Validation
   ===================================================================================

   PURPOSE: Test if OutSystems parameters are working correctly

   SETUP in OutSystems:
   1. SiteId (Long Integer) - Expand Inline: No
   2. Date (Date) - Expand Inline: No
   3. SelectedView (Text) - Expand Inline: No

   ===================================================================================
*/

-- Output structure: Hour, DayPartLabel, Sales, PercentTotal, PercentInc (5 columns - NO SortOrder!)
SELECT
    'Total Day' AS Hour,
    'Total (00-24)' AS DayPartLabel,
    18296.15 AS Sales,
    100.00 AS PercentTotal,
    5.23 AS PercentInc

UNION ALL

SELECT
    '00-01' AS Hour,
    'Overnight (00-05)' AS DayPartLabel,
    535.24 AS Sales,
    2.93 AS PercentTotal,
    -2.45 AS PercentInc

UNION ALL

SELECT
    '05-06' AS Hour,
    'Breakfast (05-11)' AS DayPartLabel,
    1250.30 AS Sales,
    6.84 AS PercentTotal,
    3.12 AS PercentInc;
