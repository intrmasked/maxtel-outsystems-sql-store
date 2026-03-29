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

## Notes
- `"—"` = em dash, shown when variance is not applicable (CloseQtyIsTheo = true)
- Var $ uses `+$` / `-$` prefix format (e.g., `+$2.50`, `-$60.50`) matching mockup
- Green = positive variance, Red = negative variance
- Bold = Total row (identified by `Cur.ItemName = "Total"`)
- Adjust CSS class names (`text-orange`, `text-red`, `text-green`, `font-italic`, `font-bold`) to match your theme
- `Abs()` = OutSystems built-in absolute value function
- `NullDecimal()` = check for NULL Var % (when TheoConsumedQty = 0)
- Style expressions use `+` to concatenate multiple classes (e.g., bold + color)
