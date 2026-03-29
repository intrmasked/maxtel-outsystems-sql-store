# OutSystems Expressions — Raw Stock List (GetRawStockList)

Shorthand: `Cur` = `GetRawItems.RawItemsList.Current`
Total row: `Cur.ItemName = "Total"`

---

## Item (Logical)
**Expression:**
```
Cur.ItemName
```
**Style:**
```
If(Cur.ItemName = "Total", "font-bold", "")
```

---

## Unit
**Expression:**
```
Cur.UnitName
```
**Style:**
```
If(Cur.ItemName = "Total", "font-bold", "")
```

---

## Starting Count
**Expression:**
```
If(Cur.StartIsTheo,
    FormatDecimal(Cur.StartingCount, 2, ".", ",") + "*",
    FormatDecimal(Cur.StartingCount, 2, ".", ","))
```
**Style:**
```
If(Cur.ItemName = "Total", "font-bold", "") +
If(Cur.StartIsTheo, " text-orange font-italic", "")
```

---

## Raw Waste
**Expression:**
```
FormatDecimal(Cur.RawWaste, 2, ".", ",")
```
**Style:**
```
If(Cur.ItemName = "Total", "font-bold", "")
```

---

## Deliveries
**Expression:**
```
FormatDecimal(Cur.Deliveries, 2, ".", ",")
```
**Style:**
```
If(Cur.ItemName = "Total", "font-bold", "")
```

---

## Transfers
**Expression:**
```
FormatDecimal(Cur.Transfers, 2, ".", ",")
```
**Style:**
```
If(Cur.ItemName = "Total", "font-bold", "")
```

---

## Units CPM
**Expression:**
```
FormatDecimal(Cur.UnitsCPM, 2, ".", ",")
```
**Style:**
```
If(Cur.ItemName = "Total", "font-bold", "")
```

---

## End Count
**Expression:**
```
If(Cur.CloseQtyIsTheo,
    FormatDecimal(Cur.EndCount, 2, ".", ",") + "*",
    FormatDecimal(Cur.EndCount, 2, ".", ","))
```
**Style:**
```
If(Cur.ItemName = "Total", "font-bold", "") +
If(Cur.CloseQtyIsTheo, " text-red font-italic", "")
```

---

## Var Qty
**Expression:**
```
If(Cur.CloseQtyIsTheo,
    "—",
    FormatDecimal(Cur.VarQty, 2, ".", ","))
```
**Style:**
```
If(Cur.ItemName = "Total", "font-bold", "") +
If(Cur.CloseQtyIsTheo, "",
    If(Cur.VarQty > 0, " text-green",
        If(Cur.VarQty < 0, " text-red", "")))
```

---

## Var $
**Expression:**
```
If(Cur.CloseQtyIsTheo,
    "—",
    If(Cur.VarDollar < 0,
        "-$" + FormatDecimal(Abs(Cur.VarDollar), 2, ".", ","),
        "+$" + FormatDecimal(Abs(Cur.VarDollar), 2, ".", ",")))
```
**Style:**
```
If(Cur.ItemName = "Total", "font-bold", "") +
If(Cur.CloseQtyIsTheo, "",
    If(Cur.VarDollar > 0, " text-green",
        If(Cur.VarDollar < 0, " text-red", "")))
```

---

## Var %
**Expression:**
```
If(Cur.CloseQtyIsTheo,
    "—",
    If(Cur.VarPercent = NullDecimal(),
        "—",
        FormatDecimal(Cur.VarPercent, 2, ".", ",") + "%"))
```
**Style:**
```
If(Cur.ItemName = "Total", "font-bold", "") +
If(Cur.CloseQtyIsTheo, "",
    If(Cur.VarPercent > 0, " text-green",
        If(Cur.VarPercent < 0, " text-red", "")))
```

---

## Row Style (apply to entire row/container)
```
If(Cur.ItemName = "Total", "font-bold", "")
```
> Alternatively, apply this at the row level instead of per-cell to keep it DRY.

---

---

# Total Variance Card (GetRawStockTotalVariance)

Shorthand: `TV` = `GetRawStockTotalVariance.List.Current`

> **Query**: `query-total-variance.sql`
> **Output Structure**: `output-structure-total-variance.json`
> **Parameters**: Same filters as the main list — @SiteIds, @StartDate, @EndDate, @ItemSearch, @ProductTypes, @CountFrequencies

---

## Setup in OutSystems

1. Add a **second Advanced SQL** node in the Data Action (same screen action that fetches the list)
2. Paste `query-total-variance.sql` (remove any DECLARE statements)
3. Add Input Parameters matching the main list query (same names, same Expand Inline settings)
4. Set Output Structure from `output-structure-total-variance.json`:
   - `TotalVarDollar` → Decimal
   - `TotalVarPercent` → Decimal
5. The query returns **exactly 1 row** — use `GetRawStockTotalVariance.List.Current` to access it

---

## Card: Total Variance Dollar

**Expression:**
```
If(TV.TotalVarDollar < 0,
    "-$" + FormatDecimal(Abs(TV.TotalVarDollar), 2, ".", ","),
    "+$" + FormatDecimal(Abs(TV.TotalVarDollar), 2, ".", ","))
```

**Style (CSS class):**
```
If(TV.TotalVarDollar > 0, "text-green",
    If(TV.TotalVarDollar < 0, "text-red", ""))
```

---

## Card: Total Variance Percent

**Expression:**
```
If(TV.TotalVarPercent = NullDecimal(),
    "—",
    FormatDecimal(TV.TotalVarPercent, 1, ".", ",") + "%")
```

**Style (CSS class):**
```
If(TV.TotalVarPercent > 0, "text-green",
    If(TV.TotalVarPercent < 0, "text-red", ""))
```

---

## Card Layout (suggested structure)

```
┌──────────────────────────┐
│  TOTAL VARIANCE          │  ← Label (static text, bold, muted color)
│  -$63.50                 │  ← TotalVarDollar expression (large font, colored)
│  -8.2%                   │  ← TotalVarPercent expression (smaller font, colored)
└──────────────────────────┘
```

- Both values share the same color logic: red when negative, green when positive
- If TotalVarPercent is NULL (no theo consumed data), show "—" instead
- Dollar value should be the larger/primary number, percent below it

---

## Notes
- `"—"` = em dash, shown when variance is not applicable (CloseQtyIsTheo = true)
- Var $ uses `+$` / `-$` prefix format (e.g., `+$2.50`, `-$60.50`) matching mockup
- Green = positive variance, Red = negative variance
- Bold = Total row (identified by `Cur.ItemName = "Total"`)
- Adjust CSS class names (`text-orange`, `text-red`, `text-green`, `font-italic`, `font-bold`) to match your theme
- `Abs()` = OutSystems built-in absolute value function
- `NullDecimal()` = check for NULL Var % (when TheoConsumedQty = 0)
- Style expressions use `+` to concatenate multiple classes (e.g., bold + color)
