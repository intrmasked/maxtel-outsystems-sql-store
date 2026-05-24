# Claude Instructions for MaxTel OutSystems SQL Store

SQL query development for OutSystems Advanced SQL Block. Keep it simple, document everything, maintain context.

---

## Git Remotes

| Remote | URL | Team |
|--------|-----|------|
| `origin` | `https://github.com/TrueNorthTeamsAI/maxtel-outsystems-sql-store` | TNT |
| `heziico` | `https://github.com/intrmasked/maxtel-outsystems-sql-store.git` | heziico / personal |

Push to both if you have access (`git push origin main && git push heziico main`), otherwise push to whichever you can.

---

## Core Principles

1. **Simplicity First** - Write SQL a junior dev can understand
2. **OutSystems Compatible** - Standard SQL only, no fancy DB-specific functions
3. **Document Everything** - Why, not just what
4. **Aggregates First, SQL Second** - Prefer OutSystems Aggregates unless SQL is genuinely faster or necessary

---

## Aggregates vs Advanced SQL

**Default to Aggregates** for data fetching in Server Actions.

**Use Aggregates when:** Simple CRUD, standard lookups, count checks, basic joins (1-3 tables), entity actions (Create/Update/Delete).

**Use Advanced SQL when:** TOP 1 per group, CROSS JOIN, complex date math (`DATEADD`, recursive CTEs), CY/PY UNION ALL pattern, window functions, conditional aggregation, STRING_SPLIT / Expand Inline, 4+ table joins with complex conditions.

---

## OutSystems Server Action Convention

- **Server Actions** in `_CS` modules: **private** (Public = No)
- Create a **Service Action** as the public wrapper
- UI modules consume the Service Action, never the Server Action directly

---

## Story Workflow (When User Says "Start")

1. **Understand the story** - Clarify requirements briefly
2. **HARD RULE: Require story link** - Block ALL work until user provides the Azure DevOps story link. Only exception: utility queries in `queries/utilities/`. Add as `**Story Link:**` in session context.
3. **Ask for mock link** (soft rule) - If provided, add as `**Mock:**` and use `WebFetch` to scrape layout/data requirements (focus on body content, ignore sidebar nav). Mock links hosted on surge.sh.
4. **Check table docs** - Read `database-context/tables/[table-name]/README.md` BEFORE asking questions or writing SQL. Verify every column name against docs. Only ask user for table info if docs don't exist or are incomplete. If missing, create docs first.
5. **Create query folder** - `queries/[category]/[story-name]/` (name from the story)
6. **Write the query** - Start simple, iterate
7. **Document it** - README.md + metadata.json
8. **Update session context** after every major change

### Folder Structure Per Query
```
queries/[category]/[story-name]/
├── query.sql               # Production query
├── README.md               # What it does, how to use it
├── metadata.json           # Date, author, category
├── output-structure.json   # OutSystems Output Structure (REQUIRED)
└── tests/                  # Test queries subfolder
    ├── test-ssms.sql       # DECLARE params for sandbox testing
    └── test-[name].sql
```

---

## SalesFact Quirks

- **DOUBLE COUNT TRAP**: SalesFact has Detail (`PosId > 0`) AND Summary (`PosId = 0`) rows. **NEVER** use `WHERE PosId IS NOT NULL`. **ALWAYS** use `WHERE PosId <> 0` (details) or `WHERE PosId = 0` (summaries).
- **DUPLICATE HEADERS**: Same `(SiteId, Date, PosId, DateTime)` can repeat. Always `GROUP BY` with `MAX(TransactionCount)` to dedup before summing.

---

## Test Queries

- All tests go in `tests/` subfolder, named `test-[name].sql`
- **SSMS format**: Use `DECLARE` for parameters, `STRING_SPLIT` for comma-separated lists, `{TableName}` placeholders
- **Single SELECT only** - OutSystems sandbox stops after first result set. Use window functions (`COUNT(*) OVER()`, `SUM() OVER()`) for verification stats in the same SELECT.

---

## SQL Compatibility & OutSystems Rules

**Target**: SQL Server 2014+ / OutSystems Advanced SQL
**Table naming**: `{TableName}` format (not `[dbo].[TableName]`)

**Banned functions** (use alternatives):
- `RIGHT()` / `LEFT()` - Use `SUBSTRING()` or `REPLICATE()`
- `FORMAT()` - Use `REPLICATE()` + `CAST()`
- `DECLARE` in production queries - Use OutSystems Input Parameters
- Direct `@Param` in CASE/WHERE - Use InputVar CTE pattern

**Supported**: `ISNULL()`, `NULLIF()`, `COALESCE()`, `CAST()`, `CONVERT()`, `AT TIME ZONE`, window functions, conditional SUM.

**InputVar CTE Pattern** (fixes "Lazy Parser" bug where OutSystems loses track of params used late in query):
```sql
WITH
InputVar AS (SELECT @ParameterName AS Val),  -- MUST be first CTE
OtherCTEs AS (...)
SELECT ... WHERE Col = (SELECT Val FROM InputVar)
```
Use for ANY query with input parameters in CASE/WHERE statements.

**OutSystems Input Parameters**: Remove all `DECLARE` statements. Name matches SQL variable (without @). Set `Expand Inline = No` for most params.

**Comma-separated lists (multi-site)**: Use `Expand Inline = YES` so OutSystems injects literal values into `IN (...)`. For SSMS testing, use `STRING_SPLIT()` in `tests/test-ssms.sql` instead.

**Hour formatting example** (since `RIGHT()` is banned):
```sql
REPLICATE('0', 2 - LEN(CAST(hour AS VARCHAR))) + CAST(hour AS VARCHAR)
```

**No SortOrder/ORDER BY in production queries** - OutSystems handles sorting. Only use in test queries.

---

## Query Performance & Optimization

**1. UNION ALL for CY + PY** (16x faster - proven):
Separate CY/PY CTEs run sequentially. UNION ALL forces parallel index seeks.
```sql
RawDataPoints AS (
    SELECT Pod, NetAmount AS CY_Sales, 0 AS PY_Sales
    FROM {SalesFact} WHERE CalendarDate BETWEEN @StartDate AND @EndDate
    UNION ALL
    SELECT Pod, 0, NetAmount
    FROM {SalesFact} WHERE CalendarDate BETWEEN DATEADD(DAY,-364,@StartDate) AND DATEADD(DAY,-364,@EndDate)
),
AggregatedData AS (
    SELECT Pod, SUM(CY_Sales) AS CY_Sales, SUM(PY_Sales) AS PY_Sales
    FROM RawDataPoints GROUP BY Pod
)
```

**2. Pre-aggregate before scaffold** - Aggregate raw data first, then CROSS JOIN to scaffold, then LEFT JOIN.

**3. Derive from existing data** - Never add extra DB scans. Derive ActivePods from AggregatedData CTE, not a separate query.

**4. RECOMPILE hint** - Use `OPTION (RECOMPILE)` for date range queries so SQL Server optimizes for actual values. **WARNING**: Do NOT use RECOMPILE with `STRING_SPLIT` queries (causes bad cardinality estimates). Safe with `Expand Inline = YES`.

**General rules**: Minimize DB hits, filter early, use window functions for totals, avoid N+1 patterns.

**Full YoY template**: See `database-context/patterns/yoy-date-range-template.sql`

### Index Recommendations
Document in query README.md only (not in query.sql). Format:
```markdown
## Index Recommendations
1. **IX_Table_Col1_Col2** (Col1, Col2) - Impact: High - Status: Recommended
```

---

## Default Parameter Values

```sql
-- Standard test values
DECLARE @SiteId BIGINT = 3187;
DECLARE @ConceptId BIGINT = 129;
DECLARE @BusinessUserId BIGINT = 317646;  -- Abdul Haseeb @ site 3187
DECLARE @Date DATE = 'YYYY-MM-DD';
DECLARE @SelectedView VARCHAR(1) = 'D';   -- D=Dollar, G=Guest, A=AvgCheck
```

**Query header template:**
```sql
-- =============================================
-- Query: [Query Name]
-- Purpose: [Brief description]
-- Target: SQL Server 2014+
-- Created: YYYY-MM-DD
-- =============================================
```

**Finding a different BusinessUserId:**
```sql
SELECT bu.Id AS BusinessUserId, bu.IsActive, bu.HomeSiteId
FROM {BusinessUser} bu
INNER JOIN {Person} p ON p.Id = bu.PersonId
WHERE p.Name LIKE '%FirstName%'
```
Also at: `queries/report-control/grouped-reports/tests/test-find-business-user.sql`

---

## Session Context

### Folder Structure
```
.claude/sessions/
├── [feature]/
│   ├── prd.md                    # Shared PRD for the feature
│   └── [story-name]-context.md   # Story-specific session
├── standalone/
│   └── [query-name]-context.md
```

### Update Rules
**Update `.claude/sessions/[feature]/[story-name]-context.md` after EVERY change** - query modifications, table changes, user feedback, decisions, error fixes. Session context is for the team so anyone can pick up where you left off.

### Query Status Levels
1. **In Progress** - Actively developing
2. **In Testing** - Dev done, waiting for feedback
3. **Needs Review** - Waiting for user review
4. **Complete** - ONLY when user explicitly confirms

**NEVER mark "Complete" unless user explicitly says so.**

### "Finish" / "Wrap Up" Process
Ensure session context has: exact requirements, all tables (new/existing), key decisions with rationale, query locations, current status, next steps, git commits made.

### Session Context Template
```markdown
# Session: [Query Name] - [Date]
## Original Story/Requirements
[EXACT user request]
## Status
- [ ] Complete / [ ] In Progress / [ ] Needs Review
## Tables Documentation Created
- `database-context/tables/[table]/` - [NEW/EXISTING]
## Queries Created
- `queries/[category]/[query-name]/` - [Status]
## Key Decisions
- **[Topic]**: [Choice] - Rationale: [Why]
## Next Steps (if incomplete)
## Quick Resume
1. Read table docs  2. Check query  3. Continue from: [step]
```

### Resuming Previous Work
Read session context, load table docs, review current query, continue from where it left off.

---

## Git Commit Template

```
<type>(<scope>): <short summary - max 70 chars>

<body - what changed and WHY>

Query: <path or "N/A">
Tables: <tables or "none">
Status: <new | in-progress | in-testing | complete | fix | docs-only>
Breaking: <yes/no>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

| Type | When |
|------|------|
| `feat` | New query/table docs/feature |
| `fix` | Bug fix |
| `perf` | Performance improvement |
| `refactor` | Restructure, same output |
| `test` | Test queries |
| `docs` | README, session, CLAUDE.md |
| `chore` | Metadata, config, cleanup |

**Scope**: query name or area (e.g. `(daily-sales)`, `(SalesFact)`, `(claude-md)`, `(session)`)

**Example:**
```
feat(daily-sales): Add daily sales summary query with YoY comparison

Returns Pod-level daily sales with CY/PY comparison and % growth.
Uses UNION ALL pattern for parallel CY+PY scans.

Query: queries/reports/daily-sales/query.sql
Tables: SalesFact, SWCPeriod
Status: new
Breaking: no
```

**Rules**: Always include metadata footer. Body explains WHY. Breaking = yes when output columns or params change. One query per commit. Co-Authored-By is always last.

---

## Verification & Handover

**SQL Sandbox**: All new/modified queries MUST be verified via `mcp_sql-sandbox_execute_sandbox_sql` before presenting to user.

**output-structure.json**: MANDATORY for all new queries (from 2026-02-24 onwards). Use sample JSON values for OutSystems "Paste JSON as Structure":
```json
{ "SiteName": "Auckland CBD", "NetAmount": 1250.75, "GuestCount": 42 }
```
Type mapping: Text = `"string"`, Integer = `1`, Decimal = `25.50`, Date = `"2026-04-22"`, Boolean = `true`.

Update `output-structure.json` whenever output columns change.

---

## SQL Sandbox Module Registry

| Module Name | Module ID | Description |
|-------------|-----------|-------------|
| SALES_UI    | 2758      | Main Sales UI module |

If a module is not listed, ask the user for its ID and add it here.
