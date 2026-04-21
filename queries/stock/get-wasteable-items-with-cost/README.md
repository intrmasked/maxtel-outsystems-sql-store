# Query: Get Wasteable Items With Cost

**Category**: Stock
**Story**: 1.7 — Raw Waste — GetOrCreate RawWasteCount Rows
**Status**: New
**Created**: 2026-04-21

---

## Purpose

Returns one row per **wasteable LogicalItem × DayPart** for a given site, with `CostPerUnit` resolved from the most recent `BO_RawItemPrice`.

Used by the `InitRawWasteCount` Server Action to bulk-create `RawWasteCount` rows when a user first opens a date in the Raw Waste UI.

---

## When This Query Runs

1. User opens a date in Raw Waste UI
2. Server Action calls `GetOrCreateStockPeriod(SiteId, Date)` → `StockPeriodId`
3. Aggregate checks: do `RawWasteCount` rows already exist for this `StockPeriodId`?
4. If **no rows** → this query runs to fetch the item × shift matrix
5. Server Action loops results and calls `CreateRawWasteCount` per row

---

## Input Parameters

| Name | Type | Expand Inline | Description |
|------|------|---------------|-------------|
| `SiteId` | Long Integer | No | The site to fetch wasteable items for |

---

## Output Structure

| Column | Type | Description |
|--------|------|-------------|
| `LogicalItemId` | Long Integer | FK → LogicalItem |
| `DayPartsId` | Long Integer | FK → DayParts (the shift) |
| `CostPerUnit` | Decimal | BO_RawItemPrice.Value / PhysicalItem.UnitsInCarton |

---

## Tables Used

| Table | Role | Join Type |
|-------|------|-----------|
| `{LogicalItem}` | Base — all logical items | FROM |
| `{LogicalItemSiteConfig}` | Filter — IsActive + IsWasteable for site | INNER JOIN |
| `{PhysicalItem}` | Resolve UnitsInCarton + price lookup keys | INNER JOIN |
| `{DayParts}` | Build item × shift matrix | CROSS JOIN |
| `{BO_RawItemPrice}` | Most recent price per item | OUTER APPLY TOP 1 |

---

## CostPerUnit Resolution

```
CostPerUnit = BO_RawItemPrice.Value / PhysicalItem.UnitsInCarton
```

- Price found via: PhysicalItem.ConceptId + PhysicalItem.WrinNumber → BO_RawItemPrice (most recent Effective <= today)
- If no price exists → defaults to 0
- If UnitsInCarton is NULL or 0 → defaults to 0
- CostPerUnit is snapshot at row creation — never updated after

---

## Why Advanced SQL (not Aggregate)

- **CROSS JOIN** — builds the Item × Shift matrix. Aggregates don't support CROSS JOIN
- **OUTER APPLY TOP 1** — gets the most recent price per item. Aggregates can't do per-group TOP 1
- Both are fundamental to this query, not optimisations

---

## Test Queries

- `tests/test-ssms.sql` — Full query with extra columns (ItemName, ShiftLabel, UnitName, RawPrice) and verification window functions for sandbox testing

---

## Index Recommendations

**Status**: Recommended (Pending DBA review)

1. **IX_LogicalItemSiteConfig_SiteId_IsActive_IsWasteable** (SiteId, IsActive, IsWasteable) INCLUDE (LogicalItemId)
   - Impact: Medium
   - Reason: INNER JOIN filter on SiteId + IsActive + IsWasteable
   - Status: Recommended

2. **IX_BO_RawItemPrice_ConceptId_WRIN_Effective** (ConceptId, WRIN, Effective DESC) INCLUDE (Value)
   - Impact: High
   - Reason: OUTER APPLY TOP 1 price lookup — needs efficient seek
   - Status: Recommended
