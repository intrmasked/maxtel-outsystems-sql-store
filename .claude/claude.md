# Claude Instructions for MaxTel OutSystems SQL Store

SQL query development for OutSystems Advanced SQL Block. Keep it simple, document everything, maintain context.

---

## Core Principles

1. **Simplicity First** - Write SQL a junior dev can understand
2. **OutSystems Compatible** - Standard SQL only, no fancy DB-specific functions
3. **Document Everything** - Why, not just what
4. **Aggregates First, SQL Second** - Always prefer OutSystems Aggregates over Advanced SQL unless SQL is genuinely faster or necessary

---

## Aggregates vs Advanced SQL — Decision Guide

**Default to Aggregates** for data fetching in Server Actions. Only use Advanced SQL when Aggregates can't do the job or SQL is measurably faster.

### Use Aggregates when:
- Simple CRUD: fetch, filter, sort, join 1-3 tables
- Standard lookups: Get record by Id, filter by FK, EXISTS checks
- Count checks: `COUNT(*) WHERE condition` → use a Count aggregate
- Basic joins: inner/left joins with straightforward ON conditions
- Entity actions: Create/Update/Delete → always use entity actions, never raw INSERT/UPDATE/DELETE SQL

### Use Advanced SQL when:
- **TOP 1 per group** — Aggregates can't do `ROW_NUMBER() OVER (PARTITION BY ...)` or `OUTER APPLY` with `TOP 1`
- **CROSS JOIN** — Aggregates don't support CROSS JOIN (e.g. building an Item × Shift matrix)
- **Complex date math** — `DATEADD`, recursive CTEs, date range generation
- **CY/PY UNION ALL pattern** — performance-critical year-over-year queries
- **Window functions** — `SUM() OVER(PARTITION BY ...)`, `ROW_NUMBER()`, etc.
- **Conditional aggregation** — `SUM(CASE WHEN ... THEN ... END)` across multiple dimensions
- **STRING_SPLIT / Expand Inline** — multi-site comma-separated list filtering
- **4+ table joins** with complex conditions that would be awkward in Aggregates

### Decision checklist:
1. Can an Aggregate do this? → **Use Aggregate**
2. Would it need 2-3 Aggregates chained together? → Still probably **Aggregates** (simpler to maintain)
3. Does it need TOP 1 per group, CROSS JOIN, window functions, or UNION ALL? → **Advanced SQL**
4. Is performance critical on a large table (SalesFact, StockPeriodBalance)? → **Advanced SQL** with optimisation patterns

---

## OutSystems Server Action Convention

**Always use Service Actions to expose logic from CS modules.**

- **Server Actions** in `_CS` modules should be **private** (Public = No)
- Create a **Service Action** as the public wrapper that calls the private Server Action
- This keeps the CS module's internal logic encapsulated
- UI modules consume the Service Action, never the Server Action directly

**Pattern:**
```
Stock_CS module:
├─ Server Action: SetupDefaultFavourites (Private)    ← actual logic
└─ Service Action: SetupDefaultFavourites (Public)    ← wrapper, calls the Server Action
```

---

## When User Says "Start" or Gives Story Instructions

### Automatic Workflow:

1. **Understand the story** - Clarify requirements briefly

2. **🔗🚨 HARD RULE: REQUIRE STORY LINK BEFORE STARTING** - Before starting any work:
   - **DO NOT proceed with any session work until the user provides the Azure DevOps story link**
   - Ask: "What's the Azure DevOps story link for this?"
   - **BLOCK all work** (no queries, no table docs, no session files) until the link is provided
   - **Only exception**: utility queries in `queries/utilities/` — these don't need a story link
   - Once provided, add it to the session context file as `**Story Link:**` at the top
   - Format: `https://dev.azure.com/MaxtelNZ/Scheduling/_boards/board/t/Scheduling%20Team/Stories?workitem=XXXX`
   - This links our SQL work back to the original story for traceability

2b. **🎨 ASK FOR MOCK LINK** - After getting the story link:
   - Ask: "Is there a mock/design link for this?" (not a hard rule — just ask)
   - If provided, add it to the session context file as `**Mock:**` at the top
   - Mock links are hosted on surge.sh (e.g. `https://maxtel-stock.surge.sh/...`, `https://maxtel-reports.surge.sh/...`)
   - Use `WebFetch` to scrape the mock page for layout, structure, and data requirements
   - Focus on the **body/main content area** — sidebar navigation is generally not relevant to the story

3. **🚨 ALWAYS CHECK TABLE DOCS FIRST** - Before asking ANY questions:
   - **READ** existing table docs in `database-context/tables/[table-name]/README.md`
   - Check if columns, types, and relationships are already documented
   - **ONLY ask user for table info if docs don't exist or are incomplete**
   - If table docs exist → Use them, don't ask user to repeat information

3. **🔥 ALWAYS REFER TO TABLE DOCS WHEN WRITING QUERIES** - Before writing ANY SQL:
   - **NEVER assume column names** - Always check table documentation first
   - **VERIFY every column name** against the table README before using it
   - **CHECK data types** to ensure correct handling
   - If unsure about a column name → Read the table docs again
   - **Wrong column names = query errors** - Always double-check!

3. **Check for missing table docs** - For each table needed:
   - Check if `database-context/tables/[table-name]/` exists
   - If NOT exists → **Ask user for table info** (columns, types, relationships)
   - Create `database-context/tables/[table-name]/README.md` with full table docs
   - Then proceed with query

3. **Create query folder** - `queries/[category]/[query-name]/`

4. **Write the query** - Start simple, iterate if needed

5. **Document it** - Create README.md with purpose and usage

6. **Add metadata** - Create metadata.json with date/author

**Important**:
- Each query gets its own folder. No table docs = ask for them first.
- **Update session context after EVERY major change** - This is for the team!

**Query Naming**: Always name the query folder using the story name the user provides (e.g., if story is "Daily Sales Summary", folder = "daily-sales-summary").

### Folder Structure Per Query:
```
queries/[category]/[story-name]/
├── query.sql               # The actual SQL (production query)
├── README.md               # What it does, how to use it
├── metadata.json           # Date, author, category
├── output-structure.json   # OutSystems Output Structure definition (REQUIRED)
└── tests/                  # Test queries subfolder
    ├── test-ssms.sql       # Full query with DECLARE params for sandbox testing
    ├── test-[feature].sql
    ├── test-[diagnostic].sql
    └── ...
```

### Database & Schema Quirks (SalesFact)
- **THE DOUBLE COUNT TRAP**: `SalesFact` contains both **Detailed** (`PosId > 0`) AND **Summary** (`PosId = 0`) rows.
  - **NEVER** use `WHERE PosId IS NOT NULL` (Counts double!).
  - **ALWAYS** specify `WHERE PosId <> 0` (for Details) OR `WHERE PosId = 0` (for Summaries).
- **DUPLICATE HEADERS**: Rows with same `(SiteId, Date, PosId, DateTime)` can exist multiple times.
  - **SAFEGUARD**: Always use `GROUP BY ...` with `MAX(TransactionCount)` to dedup before summing.

### Test Queries:
**All test/diagnostic queries go in the `tests/` subfolder within the query directory**
- Use descriptive names starting with `test-`
- Test queries help diagnose issues, verify data, or prototype logic
- KEEP THEM ORGANIZED in the `tests/` subfolder
- **SSMS FORMAT REQUIRED**:
  - Tests run in a sandbox environment → MUST be valid T-SQL (SSMS compatible).
  - Use `DECLARE` for parameters (not Input Parameters).
  - Use `STRING_SPLIT` for comma-separated lists (simulate `Expand Inline = YES`).
  - Use placeholders like `{TableName}` if standard, or actual table names if needed.
- Example: `queries/reports/product-sales-by-drawer/tests/test-salesfact.sql`

**🚨 CRITICAL: OutSystems Sandbox Limitation**
- **NEVER use multiple SELECT statements** in test queries
- OutSystems sandbox **stops after the first result set**
- ❌ WRONG: `SELECT '=== Section 1 ===' AS Header; SELECT * FROM Table;`
- ✅ CORRECT: Use a **single SELECT with window functions** for verification stats
  ```sql
  -- CORRECT: Single SELECT with verification columns
  SELECT
      cd.PosId,
      cd.Amount,
      -- Verification columns using window functions
      COUNT(*) OVER() AS Total_Rows,
      SUM(cd.Amount) OVER() AS Total_Amount,
      MIN(cd.Amount) OVER() AS Min_Amount,
      MAX(cd.Amount) OVER() AS Max_Amount
  FROM {Table} cd;
  ```
- Use **window functions** (OVER clause) to include aggregated stats in a single result set
- Add descriptive comments to explain what each section does

### Table Documentation Guidelines:
- Table docs in `database-context/tables/` are **universal** - used by ALL queries
- Keep them generic and non-query-specific
- Only add `images/` folder if visual aids are needed (usually not required)
- Focus on: columns, types, relationships, common patterns

### Query SQL Structure:
**Always start queries with DECLARE statements for parameters:**
```sql
-- =============================================
-- Query: [Query Name]
-- Purpose: [Brief description]
-- Target: SQL Server 2014+
-- Created: YYYY-MM-DD
-- =============================================

-- Parameters
DECLARE @SiteId BIGINT = 3187;  -- Default SiteId
DECLARE @Date DATE = '2025-01-15';

-- Query starts here
SELECT ...
```
This allows easy testing by changing values at the top.

**Default Values:**
- `@SiteId` = 3187 (standard test site)
- `@ConceptId` = 129 (standard test concept)
- `@Date` = Current or test date in 'YYYY-MM-DD' format
- `@SelectedView` = 'D' (if query uses view parameter)
  - 'D' = Dollar Sales (NetAmount)
  - 'G' = Guest Count (TransactionCount)
  - 'A' = Average Check (NetAmount / TransactionCount)

**After any query changes**: Update session context with what changed and why.

### SQL Server Compatibility & OutSystems Requirements:

**🚨 CRITICAL: ALWAYS use OutSystems-compatible SQL functions ONLY**

- **Target**: SQL Server 2014+ / OutSystems Advanced SQL
- **Table naming**: Use `{TableName}` format (NOT `[dbo].[TableName]`)
  - Example: `FROM {SWCPeriod} p` instead of `FROM [dbo].[SWCPeriod] p`
  - This is OutSystems convention for table references

**🔥 CRITICAL OutSystems Quirk - "Lazy Parser" Parameter Bug:**
- **Issue**: Long queries with parameters used only at the end fail with "Must declare scalar variable"
- **Root Cause**: OutSystems scans queries top-down; if parameter isn't seen early, it stops tracking it
- **REQUIRED FIX**: Always add InputVar CTE as FIRST CTE in WITH clause
- **Pattern**:
  ```sql
  WITH
  InputVar AS (SELECT @ParameterName AS Val),  -- MUST be first CTE
  OtherCTEs AS (...)
  SELECT ... WHERE Col = (SELECT Val FROM InputVar)
  ```
- **When to use**: ANY query with input parameters used in CASE/WHERE statements

**❌ NEVER USE these functions (OutSystems doesn't support them):**
- ❌ `RIGHT()` - Use `SUBSTRING()` or `REPLICATE()` instead
- ❌ `LEFT()` - Use `SUBSTRING()` instead
- ❌ `FORMAT()` in SQL Server 2008/2012 - Use `REPLICATE()` + `CAST()` instead
- ❌ `DECLARE` statements - Use OutSystems Input Parameters instead
- ❌ Direct parameter in CASE/WHERE - OutSystems may not bind parameters correctly

**✅ ALWAYS USE OutSystems-compatible alternatives:**
- ✅ `REPLICATE('0', 2 - LEN(CAST(value AS VARCHAR))) + CAST(value AS VARCHAR)` instead of `RIGHT('0' + value, 2)`
- ✅ `SUBSTRING(text, start, length)` instead of `LEFT()` or `RIGHT()`
- ✅ **InputVar CTE pattern** for parameter binding:
  ```sql
  InputVar AS (SELECT @ParameterName AS Val)
  -- Then use: (SELECT Val FROM InputVar) in CASE/WHERE
  ```
- ✅ `ISNULL()`, `NULLIF()`, `COALESCE()` - all supported
- ✅ `CAST()`, `CONVERT()` - supported
- ✅ `AT TIME ZONE` - supported (SQL Server 2016+)
- ✅ **Window functions** - Use for totals instead of joins (e.g., `SUM() OVER(PARTITION BY ...)`)
- ✅ **Conditional SUM** - Combine multiple queries into one scan (e.g., `SUM(CASE WHEN ... THEN ... ELSE 0 END)`)

**OutSystems Input Parameters:**
- Remove ALL `DECLARE @Variable` statements from query
- Add parameters in OutSystems Advanced SQL block:
  - Name matches SQL variable name (without @)
  - Set **Expand Inline = No** for most parameters
  - OutSystems automatically converts to `@ParameterName` in SQL

**🔥 CRITICAL: Comma-Separated Lists (Multi-Site Support):**
- **Problem**: SQL Server can't use `IN (@StringParam)` - it treats the whole string as one value
- **Solution**: Use OutSystems **Expand Inline = YES** for comma-separated parameters!
- When `Expand Inline = YES`, OutSystems injects values directly into SQL text:
  ```sql
  -- You write:
  WHERE SiteId IN (@SiteIds)
  
  -- OutSystems generates (when @SiteIds = '3187,3188,3189'):
  WHERE SiteId IN (3187,3188,3189)
  ```
- **When to use**: Multi-site queries where OutSystems passes comma-separated Site IDs
- **Security**: OutSystems handles tenant filtering in application layer, then passes safe list

**Comma-Separated List Pattern:**
```sql
-- OutSystems Production Query (Expand Inline = YES)
SiteList AS (
    SELECT s.Id AS SiteId, ISNULL(s.DisplayName, s.Name) AS SiteName
    FROM {Site} s
    WHERE s.Id IN (@SiteIds)  -- Works with Expand Inline = YES!
)
```

**SSMS Testing for Comma-Separated Lists:**
- Expand Inline only works in OutSystems, NOT in SSMS
- For SSMS testing, create a separate test file using `STRING_SPLIT()`:
  ```sql
  -- SSMS Test Version (SQL Server 2016+)
  WHERE s.Id IN (SELECT CAST(value AS BIGINT) FROM STRING_SPLIT(@SiteIds, ','))
  ```
- Keep SSMS test queries in `tests/test-ssms.sql` subfolder
- Production query stays clean (OutSystems-specific)

**Example 1 - Hour Formatting (OutSystems compatible):**
```sql
-- ❌ WRONG (uses RIGHT - doesn't work in OutSystems)
RIGHT('0' + CAST(hour AS VARCHAR), 2)

-- ✅ CORRECT (uses REPLICATE - works in OutSystems)
REPLICATE('0', 2 - LEN(CAST(hour AS VARCHAR))) + CAST(hour AS VARCHAR)
```

**Example 2 - CASE with Parameters (OutSystems compatible):**
```sql
-- ❌ WRONG (OutSystems may not bind parameters correctly)
CASE @SelectedView
    WHEN 'D' THEN NetAmount
    WHEN 'G' THEN TransactionCount
    ELSE 0
END

-- ✅ CORRECT (use InputVar CTE pattern for reliable parameter binding)
WITH InputVar AS (
    SELECT @SelectedView AS Val
)
SELECT
    CASE (SELECT Val FROM InputVar)
        WHEN 'D' THEN NetAmount
        WHEN 'G' THEN TransactionCount
        ELSE 0
    END AS Sales
FROM Table
```

**Example 3 - Optimization with Conditional SUM (Single Scan):**
```sql
-- ❌ INEFFICIENT (Two separate scans of SalesFact)
CY_Data AS (
    SELECT SUM(NetAmount) AS CY_Sales
    FROM {SalesFact}
    WHERE CalendarDate = @Date
),
PY_Data AS (
    SELECT SUM(NetAmount) AS PY_Sales
    FROM {SalesFact}
    WHERE CalendarDate = DATEADD(DAY, -364, @Date)
)

-- ✅ EFFICIENT (Single scan with conditional SUM)
RawData AS (
    SELECT
        SUM(CASE WHEN CalendarDate = @Date THEN NetAmount ELSE 0 END) AS CY_Sales,
        SUM(CASE WHEN CalendarDate = DATEADD(DAY, -364, @Date) THEN NetAmount ELSE 0 END) AS PY_Sales
    FROM {SalesFact}
    WHERE CalendarDate IN (@Date, DATEADD(DAY, -364, @Date))
)
```

### Query Performance & Optimization:

**🔥 CRITICAL LESSONS (Proven in Production):**

1. **🚀 UNION ALL Pattern for CY + PY Queries** - **16x Performance Gain!**
   - **Problem**: Separate CY and PY CTEs run sequentially (slow)
   - **Solution**: Combine with UNION ALL to force parallel index seeks
   - **Real Result**: 16 seconds → 1 second for 30-day range

   ```sql
   -- ❌ SLOW (Sequential execution - 16s for 30 days)
   CY_Data AS (
       SELECT Pod, SUM(NetAmount) AS CY_Sales FROM {SalesFact}
       WHERE CalendarDate BETWEEN @StartDate AND @EndDate
       GROUP BY Pod
   ),
   PY_Data AS (
       SELECT Pod, SUM(NetAmount) AS PY_Sales FROM {SalesFact}
       WHERE CalendarDate BETWEEN DATEADD(DAY, -364, @StartDate) AND DATEADD(DAY, -364, @EndDate)
       GROUP BY Pod
   )

   -- ✅ FAST (Parallel execution - 1s for 30 days - 16x faster!)
   RawDataPoints AS (
       SELECT Pod, NetAmount AS CY_Sales, 0 AS PY_Sales
       FROM {SalesFact}
       WHERE CalendarDate BETWEEN @StartDate AND @EndDate

       UNION ALL

       SELECT Pod, 0, NetAmount
       FROM {SalesFact}
       WHERE CalendarDate BETWEEN DATEADD(DAY, -364, @StartDate) AND DATEADD(DAY, -364, @EndDate)
   ),
   AggregatedData AS (
       SELECT Pod, SUM(CY_Sales) AS CY_Sales, SUM(PY_Sales) AS PY_Sales
       FROM RawDataPoints
       GROUP BY Pod
   )
   ```

   **Why It's Faster**:
   - SQL Server runs both queries in parallel (simultaneous index seeks)
   - Single aggregation pass over combined data
   - Forces optimal execution plan

2. **🔥 Pre-Aggregation Strategy** - Aggregate BEFORE Building Scaffold
   - **Problem**: Joining scaffold to raw data = large data volume
   - **Solution**: Aggregate raw data first, then join to scaffold
   - **Benefit**: Reduces data volume by 10-100x before joins

   ```sql
   -- ✅ CORRECT ORDER
   -- Step 1: Aggregate raw data first
   AggregatedData AS (
       SELECT Date, Pod, SUM(Sales) AS Sales
       FROM RawDataPoints
       GROUP BY Date, Pod
   ),
   -- Step 2: Build scaffold
   Scaffold AS (
       SELECT d.Date, p.Pod
       FROM DateList d
       CROSS JOIN ActivePods p
   ),
   -- Step 3: Join small aggregated data to scaffold
   FinalData AS (
       SELECT s.Date, s.Pod, ISNULL(a.Sales, 0) AS Sales
       FROM Scaffold s
       LEFT JOIN AggregatedData a ON s.Date = a.Date AND s.Pod = a.Pod
   )
   ```

3. **🔥 Derive From Existing Data** - Never Add Extra Database Scans
   - **Problem**: Adding separate query for ActivePods = extra database hit
   - **Solution**: Derive ActivePods from data you're already fetching

   ```sql
   -- ❌ WRONG (3 database hits: ActivePods + CY + PY)
   ActivePods AS (
       SELECT DISTINCT Pod FROM {SalesFact}
       WHERE CalendarDate BETWEEN @StartDate AND @EndDate
   ),
   CY_Data AS (SELECT ... FROM {SalesFact} ...),
   PY_Data AS (SELECT ... FROM {SalesFact} ...)

   -- ✅ CORRECT (2 database hits: CY + PY only)
   RawDataPoints AS (
       SELECT ... FROM {SalesFact} ... UNION ALL SELECT ...
   ),
   AggregatedData AS (
       SELECT ... FROM RawDataPoints ...
   ),
   ActivePods AS (
       SELECT DISTINCT Pod FROM AggregatedData  -- ← Derived from existing data!
       WHERE CY_Sales > 0 OR CY_Count > 0
   )
   ```

4. **🔥 RECOMPILE Hint** - For Queries with Varying Parameters
   - **Use Case**: Date range queries (7 days vs 90 days = different plans)
   - **Solution**: Add `OPTION (RECOMPILE)` to force new plan each run
   - **Benefit**: SQL Server optimizes for actual parameter values

   ```sql
   SELECT ... FROM ...
   ORDER BY Date ASC
   OPTION (MAXRECURSION 1000, RECOMPILE);  -- ← Forces optimal plan
   ```

   **⚠️ WARNING: RECOMPILE + STRING_SPLIT = Slower!**
   - `STRING_SPLIT(@SiteIds, ',')` returns unknown row count at compile time
   - When RECOMPILE forces a recompile, SQL Server can't estimate cardinality for STRING_SPLIT and guesses badly → terrible plan
   - **Result**: RECOMPILE made product-mix-list go from 1.8s → 6.8s (5 sites, 1 month)
   - **Rule**: Do NOT use `OPTION (RECOMPILE)` on queries that filter with `STRING_SPLIT`
   - RECOMPILE is safe on production queries using `Expand Inline = YES` (literal values, no variable)

**General Optimization Rules**:
- **Minimize database hits** - Derive data from existing CTEs instead of separate queries
- **Use proper indexing** - Recommend indexes for WHERE/JOIN columns
- **Filter early** - Apply WHERE filters as early as possible in subqueries
- **Aggregate wisely** - Use GROUP BY efficiently, include all non-aggregated columns
- **Window functions** - Use for totals instead of joins (e.g., `SUM() OVER(PARTITION BY ...)`)
- **Avoid N+1 patterns** - Always fetch related data in single query

### Index Recommendations:
**After building each query:**
1. Analyze WHERE clauses and JOIN conditions
2. Document index recommendations in query README.md only
3. Track index status (Recommended / Implemented / Not Needed)
4. DO NOT add index recommendations to the query.sql file itself

**Format in README.md:**
```markdown
## Index Recommendations

**Status**: Recommended (Pending DBA review)

1. **IX_TableName_Column1_Column2** (Column1, Column2)
   - Impact: High/Medium/Low
   - Reason: WHERE/JOIN filtering
   - Status: Recommended / Implemented / Not Needed
```

---

## Recommended Query Pattern for Date Range + YoY Queries

**Use this proven template for queries with Current Year + Previous Year comparison:**

```sql
-- Parameters
DECLARE @SiteId BIGINT = 3187;
DECLARE @StartDate DATE = '2025-12-01';
DECLARE @EndDate DATE = '2025-12-07';
DECLARE @SelectedView VARCHAR(1) = 'D';

WITH

-- [STEP 1]: Generate Date Range (if needed)
DateList AS (
    SELECT @StartDate AS ReportDate
    UNION ALL
    SELECT DATEADD(DAY, 1, ReportDate)
    FROM DateList
    WHERE ReportDate < @EndDate
),

-- [STEP 2]: Fetch CY + PY Data using UNION ALL (CRITICAL FOR PERFORMANCE!)
RawDataPoints AS (
    -- Query A: Current Year (Direct Index Seek)
    SELECT
        CalendarDate AS ReportDate,
        Pod,
        NetAmount AS CY_NetAmount,
        TransactionCount AS CY_TransactionCount,
        0 AS PY_NetAmount,
        0 AS PY_TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
      AND CalendarDate BETWEEN @StartDate AND @EndDate
      AND DatePeriodDimensionId = 15
      AND ProductSaleTypeId = 1
      AND ProductMenuId IS NULL
      AND TenderTypeId IS NULL
      AND OperationId IS NULL
      AND OperationKindId IS NULL
      AND SWCCashDrawerId IS NULL
      AND SaleTypeId IS NULL
      AND PosId IS NOT NULL
      AND Pod IS NOT NULL AND Pod <> ''

    UNION ALL

    -- Query B: Previous Year (Direct Index Seek)
    SELECT
        DATEADD(DAY, 364, CalendarDate) AS ReportDate,
        Pod,
        0, 0, -- CY Cols are 0
        NetAmount,
        TransactionCount
    FROM {SalesFact}
    WHERE SiteId = @SiteId
      AND CalendarDate BETWEEN DATEADD(DAY, -364, @StartDate) AND DATEADD(DAY, -364, @EndDate)
      AND DatePeriodDimensionId = 15
      AND ProductSaleTypeId = 1
      AND ProductMenuId IS NULL
      AND TenderTypeId IS NULL
      AND OperationId IS NULL
      AND OperationKindId IS NULL
      AND SWCCashDrawerId IS NULL
      AND SaleTypeId IS NULL
      AND PosId IS NOT NULL
      AND Pod IS NOT NULL AND Pod <> ''
),

-- [STEP 3]: Aggregate Combined Data (BEFORE building scaffold!)
AggregatedData AS (
    SELECT
        ReportDate,
        Pod,
        SUM(CY_NetAmount) AS CY_NetAmount,
        SUM(CY_TransactionCount) AS CY_TransactionCount,
        SUM(PY_NetAmount) AS PY_NetAmount,
        SUM(PY_TransactionCount) AS PY_TransactionCount
    FROM RawDataPoints
    GROUP BY ReportDate, Pod
),

-- [STEP 4]: Identify Active Pods (Derived from aggregated data)
ActivePods AS (
    SELECT DISTINCT Pod
    FROM AggregatedData
    WHERE CY_TransactionCount > 0 OR CY_NetAmount <> 0
),

-- [STEP 5]: Build Scaffold (Date Range x Active Pods)
Scaffold AS (
    SELECT d.ReportDate, p.Pod
    FROM DateList d
    CROSS JOIN ActivePods p
),

-- [STEP 6]: Merge Scaffold with Aggregated Data
GridData AS (
    SELECT
        s.ReportDate,
        s.Pod,
        ISNULL(a.CY_NetAmount, 0) AS CY_NetAmount,
        ISNULL(a.CY_TransactionCount, 0) AS CY_TransactionCount,
        ISNULL(a.PY_NetAmount, 0) AS PY_NetAmount,
        ISNULL(a.PY_TransactionCount, 0) AS PY_TransactionCount
    FROM Scaffold s
    LEFT JOIN AggregatedData a ON s.ReportDate = a.ReportDate AND s.Pod = a.Pod
),

-- [STEP 7]: Calculate Final Metrics with Window Functions
FinalSet AS (
    -- Individual Rows
    SELECT
        ReportDate,
        Pod,
        CY_NetAmount,
        CY_TransactionCount,
        PY_NetAmount,
        PY_TransactionCount,
        SUM(CY_NetAmount) OVER(PARTITION BY ReportDate) as DailyTotal_Net,
        SUM(CY_TransactionCount) OVER(PARTITION BY ReportDate) as DailyTotal_Txn,
        ROW_NUMBER() OVER (PARTITION BY ReportDate ORDER BY Pod) AS SortOrder
    FROM GridData

    UNION ALL

    -- Total Row
    SELECT
        ReportDate,
        'Total' AS Pod,
        SUM(CY_NetAmount),
        SUM(CY_TransactionCount),
        SUM(PY_NetAmount),
        SUM(PY_TransactionCount),
        SUM(CY_NetAmount),
        SUM(CY_TransactionCount),
        0 AS SortOrder
    FROM GridData
    GROUP BY ReportDate
)

-- [STEP 8]: Final Output with Calculations
SELECT
    ReportDate AS Date,
    Pod,

    -- Value based on SelectedView
    CASE @SelectedView
        WHEN 'D' THEN CY_NetAmount
        WHEN 'G' THEN CAST(CY_TransactionCount AS DECIMAL(18,2))
        WHEN 'A' THEN CASE WHEN CY_TransactionCount = 0 THEN 0 ELSE CY_NetAmount / CY_TransactionCount END
        ELSE 0
    END AS Value,

    -- Percent Total
    CASE
        WHEN @SelectedView = 'A' THEN 0
        WHEN @SelectedView = 'D' THEN
            CASE WHEN DailyTotal_Net = 0 THEN 0 ELSE CY_NetAmount * 100.0 / DailyTotal_Net END
        WHEN @SelectedView = 'G' THEN
            CASE WHEN DailyTotal_Txn = 0 THEN 0 ELSE CAST(CY_TransactionCount AS DECIMAL(18,2)) * 100.0 / DailyTotal_Txn END
        ELSE 0
    END AS PercentTotal,

    -- Year-over-Year Growth %
    CASE @SelectedView
        WHEN 'D' THEN
            CASE WHEN PY_NetAmount = 0 THEN 0 ELSE (CY_NetAmount - PY_NetAmount) * 100.0 / PY_NetAmount END
        WHEN 'G' THEN
            CASE WHEN PY_TransactionCount = 0 THEN 0 ELSE (CY_TransactionCount - PY_TransactionCount) * 100.0 / PY_TransactionCount END
        WHEN 'A' THEN
            CASE
                WHEN PY_TransactionCount = 0 OR CY_TransactionCount = 0 THEN 0
                WHEN (PY_NetAmount / PY_TransactionCount) = 0 THEN 0
                ELSE ((CY_NetAmount / CY_TransactionCount) - (PY_NetAmount / PY_TransactionCount)) * 100.0 / (PY_NetAmount / PY_TransactionCount)
            END
        ELSE 0
    END AS PercentInc,

    SortOrder

FROM FinalSet
WHERE ReportDate <= @EndDate
ORDER BY Date ASC, SortOrder ASC
OPTION (MAXRECURSION 1000, RECOMPILE);  -- ← CRITICAL for date range queries
```

**Why This Pattern Works:**
1. **UNION ALL**: Forces parallel index seeks (16x faster than separate CTEs)
2. **Pre-Aggregation**: Reduces data volume before building scaffold
3. **Derived ActivePods**: Zero extra database hits (derived from aggregated data)
4. **Window Functions**: Calculates totals without extra joins
5. **RECOMPILE**: Optimal execution plan for varying date ranges

**Performance Results:**
- 30-day range: 1 second (down from 16 seconds)
- 7-day range: < 500ms
- 90-day range: ~2-3 seconds

---

## Session Folder Structure

Sessions are organized by **feature** (folder) with individual **story** session files inside:

```
.claude/sessions/
├── [feature]/
│   ├── prd.md                          ← shared PRD & design for the whole feature
│   ├── [story-1]-context.md            ← story-specific session
│   └── [story-2]-context.md
├── standalone/                         ← one-off queries with no parent feature
│   └── [query-name]-context.md
```

**Rules:**
- **One PRD file per feature** — `prd.md` lives in the feature folder, shared across all stories
- **One session file per story** — story-specific context, references `prd.md` instead of duplicating it
- **Standalone queries** go in `standalone/` if they don't belong to a feature group
- **Story sessions reference the PRD** — `**PRD:** See prd.md in this folder`

---

## Session Context Updates (CRITICAL!)

### 🚨 MANDATORY: Update Session Context on EVERY Change!

**THINK on EVERY change you make:**
1. Did I modify the query? → Update session context
2. Did I add/change tables? → Update session context
3. Did user give feedback? → Update session context
4. Did I make a decision? → Update session context
5. Did I fix an error? → Update session context

**When to update `.claude/sessions/[feature]/[story-name]-context.md`:**

1. **After major decisions** - Document why you chose an approach
2. **After table changes** - New tables added, filters changed, joins updated
3. **After user feedback** - User corrections, new requirements, clarifications
4. **Before complex changes** - Save state before major refactoring
5. **After query modifications** - JOIN changes, filter updates, new columns
6. **When user says "update"** - Always update immediately
7. **After ANY code change** - Keep session context in sync with code

**IMPORTANT**: Session context is for the TEAM. Keep it updated so anyone can:
- Pick up where you left off
- Understand ALL decisions made
- See the full history of changes
- Know what's pending vs complete

### Session Update Frequency:
- **ALWAYS**: After EVERY change to code or documentation
- **MINIMUM**: After every significant change
- **IDEAL**: After each user interaction or decision
- **REQUIRED**: When user explicitly says "update" or "finish"

### 🚫 Query Completion Rules:

**NEVER mark a query as "Complete" unless:**
- User explicitly says "this is complete" or "mark it complete"
- User confirms testing passed and query is working

**Query Status Levels:**
1. **In Progress** - Actively developing
2. **In Testing** - User is testing (development done, waiting for feedback)
3. **Needs Review** - Waiting for user review
4. **Complete** - ONLY when user explicitly confirms

**DO NOT assume completion** - Always wait for user confirmation!

---

## Git Commit Template

### 🚨 MANDATORY: Use This Template for ALL Commits

Every commit in this repo must follow this format so any team member can scan the git log and understand what happened without opening files.

**Format:**
```
<type>(<scope>): <short summary — max 70 chars>

<body — what changed and WHY>

Query: <query path or "N/A">
Tables: <tables affected or "none">
Status: <new | in-progress | in-testing | complete | fix | docs-only>
Breaking: <yes/no — does this change output columns or parameters?>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

### Commit Types

| Type | When to Use |
|------|-------------|
| `feat` | New query, new table docs, new feature |
| `fix` | Bug fix, wrong filter, incorrect join |
| `perf` | Performance improvement (query optimization) |
| `refactor` | Restructure without changing output |
| `test` | Add/update test queries (test-ssms.sql, etc.) |
| `docs` | README, session context, CLAUDE.md changes |
| `chore` | Metadata, config, cleanup |

### Scope

Use the **query name** or **area** in parentheses:
- `(actual-sales)` — query-specific change
- `(daily-sales)` — query-specific change
- `(SalesFact)` — table docs change
- `(claude-md)` — CLAUDE.md instructions change
- `(session)` — session context only

### Examples

**New query:**
```
feat(daily-sales): Add daily sales summary query with YoY comparison

Returns Pod-level daily sales with CY/PY comparison and % growth.
Uses UNION ALL pattern for parallel CY+PY scans.

Query: queries/reports/daily-sales/query.sql
Tables: SalesFact, SWCPeriod
Status: new
Breaking: no
```

**Performance fix:**
```
perf(actual-sales): v3 rewrite — pre-resolve lookups, eliminate JOINs from SalesFact

Pre-resolve SWCPeriodId and BrandType→ProductMenuIds into tiny CTEs before
scanning SalesFact. Reduces fact table scan from 3 JOINs to zero.
Also replaces recursive scaffold CTE with static number generator.

Query: queries/utilities/actual-sales/query.sql
Tables: SalesFact, SWCPeriod, ProductMenu, BO_MenuItem, SalesHour
Status: complete
Breaking: no
```

**Bug fix:**
```
fix(mccafe): Apply correct WHERE pattern — use PosId <> 0 not IS NOT NULL

Previous filter caused double-counting by including summary rows (PosId = 0).
SalesFact has both Detail (PosId > 0) and Summary (PosId = 0) rows.

Query: queries/reports/mccafe-sales/query.sql
Tables: SalesFact
Status: fix
Breaking: no
```

**Output column change (breaking):**
```
feat(product-mix): Add PercentTotal column to output

Added % of daily total column. OutSystems Output Structure needs update —
new column "PercentTotal" (Decimal) added to output-structure.json.

Query: queries/reports/product-mix/query.sql
Tables: SalesFact
Status: in-testing
Breaking: yes — new output column, update OutSystems Output Structure
```

**Docs only:**
```
docs(session): Update actual-sales context with v3 performance notes

Query: N/A
Tables: none
Status: docs-only
Breaking: no
```

### Rules
1. **Always include the metadata footer** (Query/Tables/Status/Breaking)
2. **Body explains WHY**, not just what — anyone reading should understand the reasoning
3. **Breaking = yes** whenever output columns, parameter names, or parameter types change
4. **One query per commit** when possible — don't mix unrelated query changes
5. **Co-Authored-By line** is always last

---

## When User Says "Finish" or "Wrap Up"

### Automatic Wrap-Up Process:

1. **Final session context update** - Ensure `.claude/sessions/[feature]/[story-name]-context.md` has:
   - Full story/requirements (exact wording)
   - All tables used + whether they were created new
   - Key decisions with rationale
   - Query locations
   - Current status (complete/in-progress)
   - Next steps if incomplete
   - All git commits made
   - Files created and updated

2. **Make it resumable** - Anyone should be able to:
   - Read the context.md
   - Understand what was built
   - Continue from where you left off

**Template for context.md**:
```markdown
# Session: [Query Name] - [Date]

## Original Story/Requirements
[EXACT user request - copy/paste what they asked for]

## Status
- [X] Complete / [ ] In Progress / [ ] Needs Review
- Current step: [What's done, what's next]
- Incomplete items: [List what still needs to be done]

## Tables Documentation Created
- `database-context/tables/[table1]/` - [NEW/EXISTING] - [Table purpose]
- `database-context/tables/[table2]/` - [NEW/EXISTING] - [Table purpose]

## Queries Created
- `queries/[category]/[query-name]/` - [Status: done/needs-review/incomplete]
  - Purpose: [Brief description]
  - Tables used: [List]
  - Output: [What it returns]

## Key Decisions
- **[Decision topic]**: [What was chosen] → Rationale: [Why]
- **[Decision topic]**: [What was chosen] → Rationale: [Why]

## Next Steps (if incomplete)
1. [Next thing to do]
2. [After that]

## Notes for Next Session
- [Important context]
- [Things to watch out for]
- [User preferences noted]

## Quick Resume
To continue:
1. Read table docs: `database-context/tables/[table]/README.md`
2. Check query: `queries/[category]/[query-name]/query.sql`
3. Continue from: [Specific step]
```

---

## Resuming Previous Work

### When User Says "Continue [query-name]" or References Previous Session:

1. **Load the context** - Read `.claude/sessions/[feature]/[story-name]-context.md`
2. **Read table docs** - Load all tables mentioned in context
3. **Check current query** - Review `queries/[category]/[query-name]/query.sql`
4. **Understand status** - Check what's done vs what's next
5. **Continue seamlessly** - Pick up exactly where it left off

**Anyone can resume** - The context.md has everything needed to continue.

---

## SQL Writing Rules

### ✅ DO:
- Use clear table aliases (`c`, `o`, `p`, `t`, etc.)
- Start with the simplest query possible
- Add comments for complex logic
- Check `database-context/tables/` before writing
- Look at existing queries for patterns

### ❌ DON'T:
- Use complex nesting when simple works
- Use vendor-specific functions (OutSystems won't like it)
- Skip documentation
- Use vague names (`query1`, `test`)
- **Add SortOrder or ORDER BY to production queries** — OutSystems handles sorting/filtering in the application layer. Only add SortOrder in `tests/` queries for convenience.

---

## Quick Reference

| Task | Location | Action |
|------|----------|--------|
| Understand a table | `database-context/tables/[table]/README.md` | Read first |
| Create new table docs | `database-context/tables/[table]/README.md` | Ask user for info, use template |
| Find similar query | `queries/[category]/` | Browse patterns |
| Wrap up session | `.claude/sessions/[feature]/[story-name]-context.md` | Auto-create on finish |
| Resume work | `.claude/sessions/[feature]/[story-name]-context.md` | Load context, continue |
| Store query | `queries/[category]/[query-name]/` | One folder per query |

---

## Example Flow

**User**: "Create a query for active customers. Start."

**You**:
1. Check if `database-context/tables/customers/` exists
2. If NO → Ask: "I need the Customers table structure. Can you provide: columns, data types, relationships?"
3. User provides table info
4. Create `database-context/tables/customers/README.md` with full docs
5. Create `queries/customers/active-customers/query.sql`
6. Write simple SQL
7. Create README.md and metadata.json

**User**: "Finish"

**You**:
1. Create `.claude/sessions/active-customers-context.md`
2. Document: story, tables (NEW/EXISTING), decisions, status, next steps
3. Done - anyone can continue from context.md

---

**Later...**

**Different User**: "Continue active-customers"

**You**:
1. Read `.claude/sessions/active-customers-context.md`
2. Load table docs from paths in context
3. Check query status
4. Continue exactly where it left off

---

**Remember**:
- Simple SQL. Each query = new folder.
- **UPDATE SESSION CONTEXT REGULARLY** - After major changes, user feedback, decisions!
- No table docs? Ask user for table info first.
- Use `database-context/tables/template-table/README.md` as template for new tables.
- Session context.md = resume ticket for anyone to continue your work.
- Context is for the TEAM - keep it updated throughout development, not just at the end.

---

## Standard Verification & Handover

### 🚨 MANDATORY: SQL Sandbox Verification
All new or modified SQL queries **MUST** be verified via the MCP SQL Sandbox Bridge before being presented to the user.
1. Use `mcp_sql-sandbox_execute_sandbox_sql` to run the query.
2. Verify results against expectations (row count, data alignment).
3. Record visual proof of the data structure for the user.

### 🗳️ OutSystems Integration Handover
For every query intended for an Advanced SQL block, create an **`output-structure.json`** file in the query folder.
- **MANDATORY** for all new queries — create alongside `query.sql`
- **Format: Sample JSON data** — use realistic sample values so the user can paste directly into OutSystems via **"Paste JSON as Structure"** to auto-create the output structure
- OutSystems infers types from the sample values:
  - Text → `"sample text"`
  - Integer → `1`
  - Long Integer → `12345` (same as integer in JSON, set type manually in OS if needed)
  - Decimal → `25.50`
  - Date → `"2026-04-22"`
  - Boolean → `true`

**Example `output-structure.json`:**
```json
{
  "SiteName":   "Auckland CBD",
  "NetAmount":  1250.75,
  "GuestCount": 42
}
```

**When to update**: If output columns change, update `output-structure.json` at the same time as `query.sql`.

> [!NOTE]
> Do NOT update old queries that predate this rule — only create `output-structure.json` for new queries from 2026-02-24 onwards.

---

## SQL Sandbox Module Registry
Use these IDs for the MCP SQL Sandbox Bridge.

| Module Name | Module ID | Description |
| ----------- | --------- | ----------- |
| SALES_UI    | 2758      | Main Sales UI module |

> [!NOTE]
> If a module is not listed, ask the user for its ID and add it here.
