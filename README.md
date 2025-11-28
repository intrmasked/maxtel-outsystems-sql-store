# MaxTel OutSystems SQL Store

A collaborative SQL query repository designed to maintain context and enable team members to seamlessly continue work on SQL queries with Claude AI assistance.

## Purpose

This repository serves as a **persistent knowledge base** for SQL query development. It helps teams:
- Maintain conversation context across multiple sessions
- Store and reference previously developed queries
- Pick up where teammates left off with full context
- Build a searchable library of SQL solutions
- Reduce token usage by reusing established context

## Repository Structure

```
maxtel-outsystems-sql-store/
├── README.md                          # This file
├── .claude/                           # Claude AI context & conversation history
├── queries/                           # Final & active SQL queries
│   ├── reports/                       # Reporting queries
│   │   ├── [query-name]/
│   │   │   ├── query.sql             # The final query
│   │   │   ├── metadata.json         # Query metadata
│   │   │   └── README.md             # Query documentation
│   ├── transactions/                  # Transaction-related queries
│   ├── customers/                     # Customer data queries
│   ├── analytics/                     # Analytics & aggregation queries
│   └── maintenance/                   # Maintenance & admin queries
│
├── database-context/                 # Detailed table documentation (OutSystems SQL Block)
│   ├── README.md                    # How to use database context
│   └── tables/                       # Individual table documentation
│       ├── [table-name]/
│       │   ├── README.md            # Full table specification & structure
│       │   └── images/              # ER diagrams, screenshots, visual aids
│
└── sessions/                          # Chat session logs & history
    ├── YYYY-MM-DD/                   # Date-based session folders
    │   ├── [query-name]-session.md   # Session transcript & decisions
    │   ├── [query-name]-context.txt  # Claude context snapshot
    │   └── [query-name]-notes.md     # Developer notes & iterations
    └── index.md                       # Session index & quick reference
```

## Workflow

### 1. Starting a New Query

```
1. Check /contexts for relevant domain knowledge
2. Create a new folder in /queries/[category]/[query-name]/
3. Copy QUERY_TEMPLATE.md to that folder
4. Share the context files with Claude AI
5. Work iteratively on the query
```

### 2. During Development

```
1. Maintain /sessions/YYYY-MM-DD/[query-name]-session.md
   - Document assumptions & decisions
   - Log iterations & Claude responses
   - Record any performance considerations

2. Keep /sessions/YYYY-MM-DD/[query-name]-context.txt
   - Store the full Claude context used
   - Update after major revisions
   - Use to resume in a new session
```

### 3. Finalizing a Query

```
1. Place final query in /queries/[category]/[query-name]/query.sql
2. Create /queries/[category]/[query-name]/metadata.json with:
   - Author
   - Creation date
   - Last updated
   - Purpose & use cases
   - Performance notes
3. Create /queries/[category]/[query-name]/README.md with:
   - What the query does
   - Expected output format
   - Parameters (if any)
   - Related queries
```

### 4. Picking Up Where Someone Left Off

```
1. Find the query folder in /queries/[category]/[query-name]/
2. Read the README.md for overview
3. Check /sessions/ for latest session file
4. Load the context snapshot from [query-name]-context.txt into Claude
5. Resume work with full context preserved
```

## Key Files to Maintain

### Claude Context (in `/.claude/`)
- Store Claude conversation snapshots and context files
- Keep conversation history for reference
- Store reusable context for future sessions

### Database Context (in `/database-context/tables/`)
- Each table has its own folder with detailed documentation
- Includes table structure, relationships, and visual aids
- Use when building queries in OutSystems Advanced SQL Block

### Query Structure (in `/queries/[category]/[query-name]/`)
```
query-name/
├── query.sql           # The actual SQL query
├── metadata.json       # Metadata about the query
└── README.md          # Human-readable documentation
```

### Session Structure (in `/sessions/YYYY-MM-DD/`)
```
YYYY-MM-DD/
├── [query-name]-session.md    # Full conversation log
├── [query-name]-context.txt   # Snapshot of Claude context used
└── [query-name]-notes.md      # Development notes & iterations
```

## Example Session Workflow

**Day 1: Developer Alice starts a new customer report**
```
1. Creates: /queries/reports/customer-churn/
2. Creates: /sessions/2025-01-15/customer-churn-session.md
3. Shares database context with Claude
4. Develops query iteratively
5. Saves Claude context to: /sessions/2025-01-15/customer-churn-context.txt
```

**Day 2: Developer Bob needs to refine the query**
```
1. Finds query in /queries/reports/customer-churn/
2. Reads /queries/reports/customer-churn/README.md
3. Opens /sessions/2025-01-15/customer-churn-session.md to understand history
4. Loads /sessions/2025-01-15/customer-churn-context.txt into Claude
5. Continues work with full context preserved
6. Updates session file with new findings
```

## Naming Conventions

- **Query folders**: Use kebab-case (e.g., `customer-churn`, `revenue-by-region`)
- **Session files**: `YYYY-MM-DD/[query-name]-session.md`
- **Context files**: descriptive names in kebab-case with `.md` extension
- **SQL files**: Always named `query.sql` for consistency

## Getting Started

1. Familiarize yourself with `/contexts/` - this is your knowledge base
2. Review existing queries in `/queries/` to see patterns
3. Check `/sessions/` to understand how conversations are documented
4. Use templates from `/templates/` when creating new entries
5. When working with Claude, paste relevant context from `/contexts/`

## Best Practices

✅ **Do**
- Keep context files updated as domain knowledge evolves
- Document assumptions and decisions in session logs
- Save Claude context snapshots before complex sessions end
- Use descriptive folder/file names
- Link related queries in README.md files
- Reference specific tables & columns in documentation

❌ **Don't**
- Store sensitive production data
- Keep raw chat transcripts without structure
- Forget to update metadata when queries change
- Use vague query names (avoid `query1`, `temp_query`)
- Skip context preservation between sessions

## Quick Reference

| Need | Location | Action |
|------|----------|--------|
| Understand DB schema | `/contexts/database-schema.md` | Read & share with Claude |
| Find a similar query | `/queries/[category]/` | Browse existing queries |
| Resume work from yesterday | `/sessions/YYYY-MM-DD/` | Load context snapshot |
| Check why a decision was made | `/sessions/YYYY-MM-DD/[query-name]-session.md` | Review session notes |
| Learn SQL patterns | `/contexts/common-patterns.md` | Copy reusable patterns |
| Create a new query | `/templates/QUERY_TEMPLATE.md` | Use as starting point |

## Contributing

When adding new queries or context:
1. Follow the structure outlined above
2. Use provided templates
3. Keep documentation up-to-date
4. Add sessions for complex work
5. Update context files if schema/rules change

---

**Repository Purpose**: Maintain SQL query development context for Claude AI collaboration, enabling team continuity and building a reusable query library.
