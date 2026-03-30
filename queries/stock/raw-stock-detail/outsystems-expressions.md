# OutSystems Expressions — Raw Stock Detail (GetRawStockDetail)

Shorthand: `Cur` = `GetRawItemDetails.RawStockDetailList.Current`
Total row: `Cur.RowType = "Total"`

---

## Date
**Expression:**
```
If(Cur.RowType = "Total",
    "Total",
    If(Cur.ReportDate = NullDate(), "",
        FormatDateTime(Cur.ReportDate, "dd MMM yyyy")))
```
**Style:**
```
If(Cur.RowType = "Total", "font-bold", "")
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
If(Cur.RowType = "Total", "font-bold", "") +
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
If(Cur.RowType = "Total", "font-bold", "")
```

---

## Deliveries
**Expression:**
```
FormatDecimal(Cur.Deliveries, 2, ".", ",")
```
**Style:**
```
If(Cur.RowType = "Total", "font-bold", "")
```

---

## Transfers
**Expression:**
```
FormatDecimal(Cur.Transfers, 2, ".", ",")
```
**Style:**
```
If(Cur.RowType = "Total", "font-bold", "")
```

---

## Units CPM
**Expression:**
```
FormatDecimal(Cur.UnitsCPM, 2, ".", ",")
```
**Style:**
```
If(Cur.RowType = "Total", "font-bold", "")
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
If(Cur.RowType = "Total", "font-bold", "") +
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
If(Cur.RowType = "Total", "font-bold", "") +
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
If(Cur.RowType = "Total", "font-bold", "") +
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
If(Cur.RowType = "Total", "font-bold", "") +
If(Cur.CloseQtyIsTheo, "",
    If(Cur.VarPercent > 0, " text-green",
        If(Cur.VarPercent < 0, " text-red", "")))
```

---

## Row Style (apply to entire row/container)
```
If(Cur.RowType = "Total", "font-bold", "")
```
> Apply at row level instead of per-cell to keep it DRY.

---

---

# Item Detail Card (GetRawStockItemDetail)

Shorthand: `Item` = `GetRawStockItemDetail.List.Current`

> **Query**: `query-item-detail.sql`
> **Output Structure**: `output-structure-item-detail.json`
> **Parameters**: `@LogicalItemId` (Expand Inline = No)

---

## Setup in OutSystems

1. Add a **second Advanced SQL** node in the Data Action
2. Paste `query-item-detail.sql` (remove any DECLARE statements)
3. Add Input Parameter: `LogicalItemId` (Long Integer, Expand Inline = No)
4. Set Output Structure from `output-structure-item-detail.json`:
   - `ItemName` → Text
   - `ItemType` → Text (resolved: Food, Paper, Supplies, etc.)
   - `WrinNumber` → Text
   - `UnitName` → Text
   - `CountFrequency` → Text (resolved: Daily, Weekly, Monthly, Never)
5. The query returns **exactly 1 row** — use `GetRawStockItemDetail.List.Current` to access it

---

## Card: Item Type
**Label:** `Item Type`
**Expression:**
```
Item.ItemType
```

---

## Card: Count Frequency
**Label:** `Count Frequency`
**Expression:**
```
Item.CountFrequency
```
> Resolved in SQL via JOIN to `{CountPeriod}`. Returns "Daily", "Weekly", "Monthly", "Never", or "—" if NULL.

---

## Card: WRIN
**Label:** `WRIN`
**Expression:**
```
Item.WrinNumber
```

---

## Card: Unit
**Label:** `Unit`
**Expression:**
```
Item.UnitName
```

---

## Breadcrumb: Item Name
**Expression:**
```
Item.ItemName
```
> Used in the breadcrumb: `Stock Ledger > [ItemName] · [SiteName]`

---

## Card Layout (from mockup)

```
┌─────────────────────────────────────────────────────┐
│  ITEM DETAIL                                         │
│  Item Type    Count Frequency    WRIN         Unit    │
│  Food         Daily              100100102    Pattie  │
└─────────────────────────────────────────────────────┘
```

- All values are static (not date-range dependent)
- Card sits in top-right of detail screen
- Labels are muted/small, values are bold


---

## Notes
- `"—"` = em dash, shown when variance is not applicable (CloseQtyIsTheo = true)
- Var $ uses `+$` / `-$` prefix format (e.g., `+$16.50`, `-$22.00`) matching mockup
- Green = positive variance, Red = negative variance
- Orange italic with `*` = theoretical starting count (StartIsTheo = true)
- Red italic with `*` = theoretical end count (CloseQtyIsTheo = true)
- Bold = Total row (identified by `Cur.RowType = "Total"`)
- `Abs()` = OutSystems built-in absolute value function
- `NullDecimal()` = check for NULL Var % (when TheoConsumedQty = 0)
- `NullDate()` = check for NULL ReportDate (Total row)
- `NullIdentifier()` = check for NULL DefaultCountPeriodId
- Footnote from mockup: `* Starting count derived from theoretical end count — no actual count was recorded for the prior period. † End count in italic indicates theoretical only — no actual count entered.`
