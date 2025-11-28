# MaxTel OutSystems SQL Store

**Purpose**: Collaborative SQL query repository with full context tracking. Built for seamless Claude AI workflow.

---

## 🤖 For Claude AI

### When User Says: "Work on [query-name]"

**Auto-load sequence:**
1. Read `.claude/sessions/[query-name]-context.md` first (resume ticket)
2. Load all table docs mentioned in context
3. Read `queries/[category]/[query-name]/query.sql`
4. Check metadata.json for status
5. Continue from current step in context

### When User Says: "Start new query" or "Create [story-name]"

**Auto-create sequence:**
1. Ask for story requirements
2. Check for table docs needed
3. If missing → Ask for table structure, create docs
4. Create `queries/[category]/[story-name]/` folder
5. Build query.sql with DECLARE pattern
6. Create README.md, metadata.json, WORKFLOW.md
7. Save session context to `.claude/sessions/[story-name]-context.md`

### Key Rules
- **Session context = resume ticket** - Read it first, always
- **Table docs are universal** - Reusable across all queries
- **Query naming** - Use exact story name in kebab-case
- **DECLARE at top** - Parameters always at top of query.sql
- See `.claude/claude.md` for full workflow instructions

---

## 📂 Repository Structure

```
maxtel-outsystems-sql-store/
├── .claude/
│   ├── claude.md                      # Claude workflow instructions (READ THIS)
│   └── sessions/
│       └── [query-name]-context.md    # Resume tickets for each query
│
├── database-context/
│   └── tables/
│       └── [table-name]/
│           └── README.md              # Universal table docs (reusable)
│
├── queries/
│   └── [category]/
│       └── [story-name]/
│           ├── query.sql              # SQL with DECLARE params at top
│           ├── README.md              # Query documentation
│           ├── metadata.json          # Tracking info
│           └── WORKFLOW.md            # Process guide
│
└── README.md                          # This file
```

## 🚀 Quick Start

### For Developers

**Starting new query:**
```
You: "I need a query for [describe requirement]. Start."
Claude: (auto-creates everything)
```

**Continuing existing query:**
```
You: "Work on product-sales-by-drawer"
Claude: (auto-loads context and continues)
```

**Wrapping up:**
```
You: "Finish" or "Wrap up"
Claude: (creates session context for resumability)
```

### For Claude (Auto-Workflow)

**User says "work on X":**
→ Load `.claude/sessions/X-context.md`
→ Load table docs
→ Check `queries/**/X/query.sql`
→ Continue seamlessly

**User says "start" or gives story:**
→ Clarify requirements
→ Check/create table docs
→ Build query with DECLARE pattern
→ Document everything
→ Save session context

**User says "finish":**
→ Create comprehensive session context
→ Mark status (complete/in-progress)
→ List next steps
→ Enable anyone to continue

## 📋 Current Queries

| Query | Status | Location | Description |
|-------|--------|----------|-------------|
| Product Sales By Drawer | In Progress | `queries/reports/product-sales-by-drawer/` | Cash drawer reconciliation with GT values and sales |

**To work on a query**: Tell Claude "work on [query-name]"

---

## 🗂️ Available Tables

| Table | Purpose | Docs |
|-------|---------|------|
| SWCCashDrawer | Cash drawer sessions & GT values | `database-context/tables/SWCCashDrawer/` |
| SWCPosTerminal | POS terminal session data | `database-context/tables/SWCPosTerminal/` |
| SWCCashDrawerTender | Tender-specific refunds & amounts | `database-context/tables/SWCCashDrawerTender/` |
| SalesFact | Sales transactions & tax | `database-context/tables/SalesFact/` |

**Table docs are universal** - Reusable across all queries

## 💡 Key Concepts

### Session Context = Resume Ticket
Every query has a context file in `.claude/sessions/[query-name]-context.md`:
- Original requirements (exact wording)
- What's done vs what's pending
- All decisions with rationale
- Next steps clearly listed
- **Anyone can pick up and continue**

### Table Docs = Universal Reference
Table docs in `database-context/tables/` are:
- **Reusable** - Used by all queries
- **Generic** - Not tied to specific queries
- **Complete** - Columns, types, relationships, patterns

### Queries = Story-Based
- Named after user story (e.g., "Product Sales By Drawer")
- DECLARE parameters at top for easy testing
- Comprehensive docs (README, metadata, workflow)
- TODO markers for incomplete items

---

## 🔧 Workflow Commands

| You Say | Claude Does |
|---------|-------------|
| "Start new query for [X]" | Creates everything from scratch |
| "Work on [query-name]" | Loads context and continues |
| "Finish" or "Wrap up" | Saves session context for resumability |
| "Show me all queries" | Lists current queries with status |

---

## 📚 Documentation

- **`.claude/claude.md`** - Full workflow guide for Claude
- **`.claude/sessions/[query]-context.md`** - Resume tickets per query
- **`queries/[category]/[query]/README.md`** - Query documentation
- **`database-context/tables/[table]/README.md`** - Table specs

---

**Built for seamless Claude AI collaboration. Context persists, work continues, queries evolve.**
