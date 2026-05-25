# MaxTel OutSystems SQL Store

SQL query repository for OutSystems Advanced SQL blocks. Full context tracking so Claude (or any dev) can pick up any story and continue.

---

## Using This Repo with Claude

### Start a New Story
```
You: "Start story [paste Azure DevOps link]"
```
Claude will: create a branch, check/create table docs, write queries, document everything, save session context.

### Resume Existing Work
```
You: "Continue working on [story-name]"
```
Claude will: read `.claude/sessions/[feature]/[story-name]-context.md`, load table docs, pick up from where it left off.

### Wrap Up
```
You: "Finish" or "Wrap up"
```
Claude will: update session context with current status, decisions, and next steps. Anyone can resume later.

All workflow rules are in `.claude/CLAUDE.md` — Claude reads this automatically.

---

## Repository Structure

```
maxtel-outsystems-sql-store/
├── .claude/
│   ├── CLAUDE.md                           # Workflow rules (Claude reads this)
│   └── sessions/
│       ├── [feature]/
│       │   ├── prd.md                      # Shared PRD for the feature
│       │   └── [story-name]-context.md     # Session context (resume ticket)
│       └── standalone/
│           └── [query-name]-context.md
│
├── database-context/
│   ├── tables/
│   │   └── [TableName]/
│   │       └── README.md                   # Table schema, relationships, patterns
│   └── patterns/
│       └── yoy-date-range-template.sql     # Reusable SQL patterns
│
├── queries/
│   ├── reports/                            # Sales, product mix, operating periods
│   ├── report-control/                     # Report config and module lists
│   ├── stock/                              # Ledger, transfers, waste
│   └── utilities/                          # Helper queries
│
└── README.md                              # This file
```

### Query Folder Structure
```
queries/[category]/[story-name]/
├── query.sql               # Production query ({TableName} format)
├── README.md               # What it does, parameters, output
├── metadata.json           # Date, author, category
├── output-structure.json   # JSON for OutSystems "Paste as Structure"
└── tests/
    ├── test-ssms.sql       # SSMS test with DECLARE params
    └── test-[name].sql
```

---

## For Developers

### Key Conventions
- **Table names**: `{TableName}` format in SQL (not `[dbo].[TableName]`)
- **No DECLARE in production queries** — use OutSystems Input Parameters
- **No ORDER BY in production queries** — OutSystems handles sorting
- **Tests**: SSMS format with `DECLARE` params, single `SELECT` only
- **Branching**: `story/[number]-[name]` branches, merge via PR

### Aggregates vs Advanced SQL
Default to OutSystems Aggregates. Use Advanced SQL only when needed (window functions, CROSS JOIN, complex date math, UNION ALL patterns, 4+ table joins).

### Table Documentation
All table docs live in `database-context/tables/[TableName]/README.md`. These are shared across all queries — check existing docs before asking for table info.

**Current tables documented**: 46 (covering Sales, Stock, Menu/Recipe, Users, Reports, Leave/Roster/PH)

### Session Context
Every story has a context file in `.claude/sessions/`. It contains: requirements, table references, key decisions, query locations, current status, and next steps. This is how work persists across sessions.

---

## Current Inventory

### Queries (25+)

| Category | Queries |
|----------|---------|
| **reports/** | cash-misc-detail, operating-periods, product-mix (3 variants), product-sales (5 variants), recipe-for-logical-item |
| **report-control/** | grouped-reports, report-module-list |
| **stock/** | ledger, transfers, waste |
| **utilities/** | actual-sales, daily-tracking, find-business-user, get-pods, get-tender-list, get-wasteable-items, migrate-favourites, period-tracking, seed-reportmodules |

### Table Domains

| Domain | Tables |
|--------|--------|
| **Sales** | SalesFact, SalesHour, SWCPeriod, SWCPosTerminal, SWCCashDrawer, SWCCashDrawerTender, TenderType, ProductSalesByOperation |
| **Stock** | PhysicalItem, LogicalItem, LogicalItemSiteConfig, LogicalItemUsage, CentralStockItem, StockMovement, StockMovementLine, StockPeriod, StockPeriodBalance, Transfer, RawWasteCount, MovementType |
| **Menu/Recipe** | BO_MenuItem, BO_MenuIngredient, BO_RawIngredient, BO_Recipe, BO_RawItemPrice, ProductMenu, DayParts |
| **Users/Org** | BusinessUser, Person, User, Site, Concept, MaxtelApp |
| **Reports** | ReportFavourites, SiteFavourite, SupportedReport, ReportModules, CountPeriod |
| **Leave/Roster/PH** | EmployeeWeek, RosterWeek, PublicHoliday, PublicHolidayReview, RosterWeekPublicHolidayReview, ScheduleStatus, OT_LeaveBalance |

---

## Git Remotes

| Remote | URL |
|--------|-----|
| `origin` | `https://github.com/TrueNorthTeamsAI/maxtel-outsystems-sql-store` |
| `heziico` | `https://github.com/intrmasked/maxtel-outsystems-sql-store.git` |

Push to both when possible.
