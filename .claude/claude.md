# Claude Instructions for MaxTel OutSystems SQL Store

SQL query development for OutSystems Advanced SQL Block. Keep it simple, document everything, maintain context.

---

## Core Principles

1. **Simplicity First** - Write SQL a junior dev can understand
2. **OutSystems Compatible** - Standard SQL only, no fancy DB-specific functions
3. **Document Everything** - Why, not just what

---

## When User Says "Start" or Gives Story Instructions

### Automatic Workflow:

1. **Understand the story** - Clarify requirements briefly

2. **🚨 ALWAYS CHECK TABLE DOCS FIRST** - Before asking ANY questions:
   - **READ** existing table docs in `database-context/tables/[table-name]/README.md`
   - Check if columns, types, and relationships are already documented
   - **ONLY ask user for table info if docs don't exist or are incomplete**
   - If table docs exist → Use them, don't ask user to repeat information

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
└── tests/                  # Test queries subfolder
    ├── test-[feature].sql
    ├── test-[diagnostic].sql
    └── ...
```

### Test Queries:
**All test/diagnostic queries go in the `tests/` subfolder within the query directory**
- Use descriptive names starting with `test-`
- Test queries help diagnose issues, verify data, or prototype logic
- Keep them organized in the `tests/` subfolder
- Example: `queries/reports/product-sales-by-drawer/tests/test-salesfact.sql`

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
  - Set **Expand Inline = No** for all parameters
  - OutSystems automatically converts to `@ParameterName` in SQL

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
- **Minimize database hits** - Optimize for fewer queries to the database
  - Use JOINs and subqueries instead of multiple separate queries
  - Aggregate data in single query when possible
  - Avoid N+1 query patterns
- **Use proper indexing** - Recommend indexes for WHERE/JOIN columns
- **Filter early** - Apply WHERE filters as early as possible in subqueries
- **Aggregate wisely** - Use GROUP BY efficiently, include all non-aggregated columns
- **Subquery optimization** - Pre-aggregate in subqueries to reduce JOIN complexity

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

## Session Context Updates (CRITICAL!)

### 🚨 MANDATORY: Update Session Context on EVERY Change!

**THINK on EVERY change you make:**
1. Did I modify the query? → Update session context
2. Did I add/change tables? → Update session context
3. Did user give feedback? → Update session context
4. Did I make a decision? → Update session context
5. Did I fix an error? → Update session context

**When to update `.claude/sessions/[query-name]-context.md`:**

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

## When User Says "Finish" or "Wrap Up"

### Automatic Wrap-Up Process:

1. **Final session context update** - Ensure `.claude/sessions/[query-name]-context.md` has:
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

1. **Load the context** - Read `.claude/sessions/[query-name]-context.md`
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

---

## Quick Reference

| Task | Location | Action |
|------|----------|--------|
| Understand a table | `database-context/tables/[table]/README.md` | Read first |
| Create new table docs | `database-context/tables/[table]/README.md` | Ask user for info, use template |
| Find similar query | `queries/[category]/` | Browse patterns |
| Wrap up session | `.claude/sessions/[name]-context.md` | Auto-create on finish |
| Resume work | `.claude/sessions/[name]-context.md` | Load context, continue |
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
