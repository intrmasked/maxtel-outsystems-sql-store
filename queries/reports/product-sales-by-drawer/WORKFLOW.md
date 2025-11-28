# Workflow & Best Practices - Product Sales By Drawer

This document explains how this query was built and how to continue/maintain it.

---

## Session Workflow (How This Was Built)

### 1. **Story Requirements Gathered**
- User provided story name: "Product Sales By Drawer"
- Collected field mappings and business logic
- Identified tables needed from OutSystems screenshots

### 2. **Table Documentation Created**
Created universal table docs in `database-context/tables/`:
- `SWCCashDrawer/` - Cash drawer sessions
- `SWCPosTerminal/` - POS terminal data
- `SWCCashDrawerTender/` - Tender-specific details
- `SalesFact/` - Sales transactions

**Key Practice**: Table docs are universal, not query-specific. Other queries can reuse them.

### 3. **Query Built**
- Created folder: `queries/reports/product-sales-by-drawer/`
- Built `query.sql` with DECLARE pattern for parameters
- Documented known logic, marked unknowns as TODO
- Added comments explaining each section

**Key Practice**: Start with DECLARE statements so parameters are easy to change.

### 4. **Documentation Created**
- `README.md` - What the query does, parameters, output columns
- `metadata.json` - Structured metadata for tracking
- `WORKFLOW.md` - This file, explaining the process

### 5. **Session Context Saved**
- `.claude/sessions/product-sales-by-drawer-context.md` created
- Contains everything needed to resume work
- Anyone can pick up where we left off

---

## How to Continue This Work

### If You're Resuming Later:

1. **Read the session context**:
   ```
   .claude/sessions/product-sales-by-drawer-context.md
   ```
   This tells you:
   - Original requirements
   - What's done vs what's pending
   - Key decisions made
   - Exact next steps

2. **Load table docs** (if needed):
   - Check `database-context/tables/` for table structures
   - Review relationships and common patterns

3. **Review current query**:
   ```
   queries/reports/product-sales-by-drawer/query.sql
   ```
   - Look at TODO comments
   - Check DECLARE parameters at top

4. **Continue from current step**:
   - Session context shows exact next actions
   - Update query with new info
   - Test and validate

---

## Best Practices Applied

### ✅ Query Structure
- **DECLARE at top** - Easy parameter changes
- **Clear comments** - Explain WHY, not just WHAT
- **TODO markers** - Explicit about unknowns
- **Section headers** - Group related logic

### ✅ Documentation
- **README.md** - User-friendly query explanation
- **metadata.json** - Machine-readable tracking
- **WORKFLOW.md** - Process documentation
- **Session context** - Full resumability

### ✅ Naming
- **Folder name** = Story name (kebab-case)
- **Clear column aliases** - Match business requirements
- **Descriptive variables** - @SiteId, @Date, not @p1, @p2

### ✅ Table Docs
- **Universal** - Not tied to this query
- **Reusable** - Other queries can reference
- **No images** - Unless truly necessary
- **Focus on facts** - Columns, types, relationships

---

## Current Status

### ✅ Complete
- Query structure built
- Known logic implemented
- TenderType mapping done
- Documentation created
- Session tracked

### ⏳ Pending
- [ ] GrossSales equation
- [ ] NetSales equation
- [ ] TenderType.Category field verification
- [ ] SiteId filter validation
- [ ] Testing with real data

### 📋 Next Actions
1. Get GrossSales equation from user
2. Get NetSales equation from user
3. Test TenderType table structure
4. Validate query results
5. Mark as complete in metadata.json

---

## How to Update This Query

### When You Get New Info:

1. **Update query.sql**:
   - Replace TODO items with actual logic
   - Remove TODO comments when resolved
   - Test changes

2. **Update README.md**:
   - Update "Known Issues / TODO" section
   - Document new fields/logic
   - Update status

3. **Update metadata.json**:
   - Change status if complete
   - Update last_updated date
   - Remove from pending_items

4. **Update session context**:
   - Mark items as complete
   - Add new decisions made
   - Update status

---

## Testing Checklist

When testing this query:

- [ ] Change DECLARE @Date to test date
- [ ] Change DECLARE @SiteId to test site
- [ ] Verify Pod values work with GetPodFullName
- [ ] Check TenderType.Category returns GC correctly
- [ ] Validate refund amounts match expectations
- [ ] Verify GST totals are accurate
- [ ] Test with multiple POS terminals
- [ ] Check NULL handling in JOINs

---

## Tips for Future Work

### When Adding New Fields:
1. Check if table doc exists in `database-context/`
2. If not, create universal table doc first
3. Add field to query
4. Document in README.md
5. Update metadata.json

### When Fixing Issues:
1. Document issue in session context
2. Fix in query.sql
3. Test thoroughly
4. Update all docs
5. Note resolution in session context

### When Someone Else Continues:
1. They read session context first
2. No need to explain from scratch
3. All decisions documented
4. Clear next steps provided

---

## File Reference

**Query Files**:
- `query.sql` - The actual SQL query
- `README.md` - User documentation
- `metadata.json` - Structured metadata
- `WORKFLOW.md` - This file

**Session Files**:
- `.claude/sessions/product-sales-by-drawer-context.md` - Full session context

**Table Docs**:
- `database-context/tables/SWCCashDrawer/README.md`
- `database-context/tables/SWCPosTerminal/README.md`
- `database-context/tables/SWCCashDrawerTender/README.md`
- `database-context/tables/SalesFact/README.md`

---

**Remember**: Session context = resume ticket. Anyone can continue your work.
