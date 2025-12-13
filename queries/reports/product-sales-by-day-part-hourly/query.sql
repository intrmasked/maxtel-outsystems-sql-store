/*
   ===================================================================================
   QUERY: FULL DRILL DOWN VIEW (Sales + GCs + AveCheck)
   ===================================================================================
   Matches the "Drill Down View" screenshot:
   - Rows: 00-01 to 23-24 plus a final "Total Day" row.
   - Columns: Sales, %Day, %Inc | GCs, %Day, %Inc | AveChq, %Inc
   ===================================================================================
*/

    DECLARE @SiteId BIGINT = 3187;
    DECLARE @Date DATE = '2025-11-25';

WITH

-- [STEP 0]: INPUTVAR PATTERN
-- Fixes OutSystems "Lazy Parser" issue and sets up dates once.
InputVars AS (
    SELECT 
        @Date AS CurrentDate,
        DATEADD(DAY, -364, @Date) AS PrevDate,
        @SiteId AS SiteIdVal
),

-- [STEP 1]: Generate 24-Hour Scaffold (00-23)
Hours AS (
    SELECT 0 AS HourNum UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
    UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11
    UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
    UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
),

HourLabels AS (
    SELECT 
        HourNum,
        -- Format: "00-01", "09-10", "23-24"
        REPLICATE('0', 2 - LEN(CAST(HourNum AS VARCHAR))) + CAST(HourNum AS VARCHAR) + '-' +
        REPLICATE('0', 2 - LEN(CAST(HourNum + 1 AS VARCHAR))) + CAST(HourNum + 1 AS VARCHAR) AS HourLabel,
        HourNum AS SortOrder -- 0 to 23
    FROM Hours
),

-- [STEP 2]: COMBINED DATA FETCH (Single Pass)
RawDataCombined AS (
    SELECT 
        -- Extract Hour
        DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time')) AS HourNum,
        
        -- Current Year Data
        SUM(CASE WHEN CalendarDate = v.CurrentDate THEN NetAmount ELSE 0 END) AS CY_NetAmount,
        SUM(CASE WHEN CalendarDate = v.CurrentDate THEN TransactionCount ELSE 0 END) AS CY_TransactionCount,

        -- Previous Year Data
        SUM(CASE WHEN CalendarDate = v.PrevDate THEN NetAmount ELSE 0 END) AS PY_NetAmount,
        SUM(CASE WHEN CalendarDate = v.PrevDate THEN TransactionCount ELSE 0 END) AS PY_TransactionCount

    FROM {SalesFact}, InputVars v
    WHERE SiteId = v.SiteIdVal 
      AND CalendarDate IN (v.CurrentDate, v.PrevDate)
      -- Core Filters
      AND DatePeriodDimensionId = 15
      AND ProductMenuId IS NULL 
      AND ProductSaleTypeId = 1
      AND TenderTypeId IS NULL 
      AND OperationId IS NULL 
      AND OperationKindId IS NULL 
      AND SWCCashDrawerId IS NULL 
      AND SaleTypeId IS NULL
      AND Pod = '' 
      AND ISNULL(PosId,0) = 0
    GROUP BY DATEPART(HOUR, CONVERT(DATETIME, [DateTime] AT TIME ZONE 'UTC' AT TIME ZONE 'New Zealand Standard Time'))
),

-- [STEP 3]: Merge Scaffold with Data
CleanedData AS (
    SELECT 
        h.HourLabel,
        h.SortOrder,
        ISNULL(r.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(r.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(r.PY_NetAmount, 0) AS PY_NetAmount,
        ISNULL(r.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM HourLabels h
    LEFT JOIN RawDataCombined r ON h.HourNum = r.HourNum
),

-- [STEP 4]: Create Total Row (Sum of all hours)
TotalRow AS (
    SELECT 
        'Total Day' AS HourLabel,
        99 AS SortOrder, -- Ensures it stays at the bottom
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM CleanedData
),

-- [STEP 5]: Combine Hours and Total, Calculate Denominators
FinalSet AS (
    SELECT 
        d.HourLabel,
        d.SortOrder,
        d.CY_NetAmount,
        d.CY_TransactionCount,
        d.PY_NetAmount,
        d.PY_TransactionCount,
        
        -- Window Functions: Get the Grand Total onto every row for % Calc
        -- We grab the values specifically from the row with SortOrder 99 (The Total Row)
        MAX(CASE WHEN d.SortOrder = 99 THEN d.CY_NetAmount END) OVER() AS GrandTotal_Net,
        MAX(CASE WHEN d.SortOrder = 99 THEN d.CY_TransactionCount END) OVER() AS GrandTotal_Txn

    FROM (
        SELECT * FROM CleanedData
        UNION ALL
        SELECT * FROM TotalRow
    ) d
)

-- [STEP 6]: Final Projection & Calculations
SELECT 
    HourLabel AS Hour,

    -- ===========================
    -- SECTION 1: SALES ($)
    -- ===========================
    CY_NetAmount AS Sales,
    
    -- Sales % of Day
    CASE 
        WHEN GrandTotal_Net = 0 THEN 0 
        ELSE (CY_NetAmount * 100.0) / GrandTotal_Net 
    END AS Sales_PctDay,

    -- Sales % Inc (YoY)
    CASE 
        WHEN PY_NetAmount = 0 THEN 0 
        ELSE ((CY_NetAmount - PY_NetAmount) * 100.0) / PY_NetAmount 
    END AS Sales_PctInc,

    -- ===========================
    -- SECTION 2: GUEST COUNTS (#)
    -- ===========================
    CAST(CY_TransactionCount AS DECIMAL(18,0)) AS GCs,

    -- GCs % of Day
    CASE 
        WHEN GrandTotal_Txn = 0 THEN 0 
        ELSE (CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0) / GrandTotal_Txn 
    END AS GCs_PctDay,

    -- GCs % Inc (YoY)
    CASE 
        WHEN PY_TransactionCount = 0 THEN 0 
        ELSE ((CAST(CY_TransactionCount AS DECIMAL(18,2)) - PY_TransactionCount) * 100.0) / PY_TransactionCount 
    END AS GCs_PctInc,

    -- ===========================
    -- SECTION 3: AVERAGE CHECK
    -- ===========================
    -- Ave Check ($)
    CASE 
        WHEN CY_TransactionCount = 0 THEN 0 
        ELSE CY_NetAmount / CY_TransactionCount 
    END AS AveChq,

    -- Ave Check % Inc (YoY)
    -- Formula: ((CY_Ave - PY_Ave) / PY_Ave) * 100
    CASE 
        WHEN CY_TransactionCount = 0 OR PY_TransactionCount = 0 THEN 0
        WHEN (PY_NetAmount / PY_TransactionCount) = 0 THEN 0
        ELSE 
            (
                (CY_NetAmount / CY_TransactionCount) - 
                (PY_NetAmount / PY_TransactionCount)
            ) * 100.0 / (PY_NetAmount / PY_TransactionCount)
    END AS AveChq_PctInc

FROM FinalSet
ORDER BY SortOrder ASC
OPTION (RECOMPILE);