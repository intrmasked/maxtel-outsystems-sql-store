# Debugging Playbook

How we diagnose and fix issues in this project. Follow this process step-by-step.

---

## Step 1: Isolate — Is It SQL or UI?

**Before touching any query code**, determine if the issue is in the SQL or the OutSystems UI.

### How to Isolate
1. Run the **production query** in the OutSystems sandbox with the exact same parameters
2. Check if the expected data appears in the raw results
3. If data IS there → **UI issue** (pagination, display limits, sorting, filtering)
4. If data is NOT there → **SQL issue** (continue to Step 2)

### Common UI Issues
- **Pagination/display limits**: OutSystems may only show N rows (e.g., 8 items). Check the list widget's `MaxRecords` or pagination settings.
- **Sorting hiding rows**: Rows may exist but be sorted to the bottom/off-screen
- **Column mapping**: OutSystems Output Structure column order must match SQL SELECT order exactly

> **Lesson learned (2026-03-25):** Recipe For Logical slideover appeared to be missing products, but the SQL returned all 65+ rows correctly. The issue was OutSystems only displaying 8 items.

---

## Step 2: Trace the Join Chain

When data IS missing from SQL results, trace the join chain step by step.

### Process
1. **Start from the expected output** — what row should appear?
2. **Find the entity** — locate it in the source table (e.g., `BO_MenuItem`)
3. **Walk each join** — run a simple SELECT at each step to verify the link exists
4. **Identify the break** — which join drops the row?

### Template Test Queries

**Find an entity by name:**
```sql
SELECT TOP 10 * FROM {TableName}
WHERE LONGNAME LIKE '%search term%' OR SHORTNAME LIKE '%search term%';
```

**Verify a specific join:**
```sql
SELECT a.*, b.*
FROM {TableA} a
INNER JOIN {TableB} b ON a.FKColumn = b.PKColumn
WHERE a.Id = @KnownId;
```

**Full chain verification (hardcode known values):**
```sql
-- Walk the chain with known IDs, no parameters, no CTEs
SELECT BRI.*, BR.*, BM.*, PM.*
FROM {BO_RawIngredient} BRI
INNER JOIN {BO_Recipe} BR ON BRI.BORecipeId = BR.Id
INNER JOIN {BO_MenuItem} BM ON BR.BOMenuItemId = BM.Refkey
INNER JOIN {ProductMenu} PM ON BM.[MIN] = PM.ProductId AND PM.ConceptId = @ConceptId
WHERE BRI.BORawItemId = @KnownRawItemId
  AND BM.Refkey = @KnownRefkey;
```

---

## Step 3: Test the Actual Query Logic

Once the raw chain is verified, test the **production query CTEs** one at a time.

### Process
1. Run just the first CTE — does it return expected data?
2. Add the next CTE — still correct?
3. Continue until you find where data drops off
4. Compare the CTE logic to the raw chain test — what's different?

### Common SQL Issues
- **Type mismatches**: `BM.MIN` may be int in DB but compared to varchar (use `CAST`)
- **Wrong column for filtering**: `BRI.WRIN` ≠ `LogicalItem.WrinNumber` (always join through LogicalItem)
- **Missing ConceptId**: Forgetting to filter by ConceptId on joined tables
- **IsDeleted filters**: Missing `IsDeleted = 0` on any table in the chain
- **UNION ALL type conflicts**: All columns must have matching types across UNION branches

---

## Step 4: Fix and Verify

1. Make the fix in `query.sql`
2. Mirror the fix in `tests/test-ssms.sql`
3. Run in sandbox with the same parameters that failed
4. Verify the previously missing data now appears
5. Update session context with what was wrong and why

---

## Known Gotchas

### BO_RawIngredient.WRIN ≠ LogicalItem.WrinNumber
- **Never filter on `BRI.WRIN = @WRIN`**
- Always resolve WRIN through LogicalItem: `LI.WrinNumber = @WRIN → LI.BO_RawItemId → BRI.BORawItemId`
- Discovered: 2026-03-25, recipe-for-logical-item query

### Combo Recipes Have Both Raw + Menu Ingredients
- A recipe with `IsCombo = true` can still have direct `BO_RawIngredient` rows
- Example: "Lrg Mac Hunger Buster NP6" is a combo but has buns as direct raw ingredients
- Always query both `BO_RawIngredient` (Path A) and `BO_MenuIngredient` (Path B)

### CAST Required for UNION ALL with MIN Column
- `BO_MenuItem.MIN` may be inferred as int by SQL Server
- When UNION ALL includes `'Total'` string → type conflict
- Fix: `CAST(BM.[MIN] AS VARCHAR(50))` in all UNION branches

### ORDER BY with UNION ALL
- SQL Server requires ORDER BY columns to be in the SELECT list when using UNION
- Add sort columns (e.g., `SortGroup`, `NullSort`) to all branches of the UNION

### OutSystems Display Limits
- List widgets may default to showing only a few rows
- Always check `MaxRecords` / pagination settings if data appears missing
- Run query in sandbox first to confirm data exists before debugging SQL
