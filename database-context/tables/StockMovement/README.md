# Table: StockMovement

**OutSystems Entity**: StockMovement
**Module**: Stock (Stock_CS)
**Purpose**: Parent record for all stock movements — deliveries, transfers, and adjustments
**Last Updated**: 2026-04-12

---

## Overview

`StockMovement` is the parent table for all stock movement transactions. Each row represents a single movement event (delivery, transfer, or adjustment). The movement type determines which extension table holds additional details (e.g., `Transfer` for transfer-type movements). Line items are stored in `StockMovementLine`.

For **transfers specifically**:
- `DeliverySiteId` = the **receiving** site
- `Date` is **null** until the transfer is approved by the receiving store
- `NetAmount`, `TaxAmount`, `GrossAmount` are calculated and written **on approval**

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | Integer | PK, NOT NULL | Primary key, auto-increment |
| `MovementTypeId` | Integer | FK, NOT NULL | FK → MovementType. Enum: 1=Adjustment, 2=Transfer, 3=Delivery |
| `DeliverySiteId` | Integer | FK, NOT NULL | FK → Site.Id. For transfers, this is the **receiving** site |
| `Date` | Date | NULL | Business date of movement. **Null for transfers until approved** |
| `NetAmount` | Decimal(18,4) | NULL | Total excl. GST. Calculated on approval for transfers |
| `TaxAmount` | Decimal(18,4) | NULL | GST amount. Calculated on approval for transfers |
| `GrossAmount` | Decimal(18,4) | NULL | Total incl. GST. Calculated on approval for transfers |
| `CreatedBy` | Integer | FK, NOT NULL | FK → User.Id. User who created the movement |
| `CreatedByUserName` | NVarChar | NULL | Denormalized snapshot of `User.Name` captured at creation time. Required because `{User}` is tenant-filtered at the Advanced SQL layer — see [Transfer → Cross-Tenant Notes](../Transfer/README.md#cross-tenant-notes) |
| `CreatedAt` | DateTime | NOT NULL | UTC timestamp of record creation |

---

## Key Constraints

### Primary Key
- `Id` — Unique identifier

### Foreign Keys
- `MovementTypeId` → `MovementType`.`Id`
- `DeliverySiteId` → `Site`.`Id`
- `CreatedBy` → `User`.`Id`

---

## Relationships

### Tables That Reference This Table
- **StockMovementLine** — Line items for this movement
  - Join: `StockMovementLine.StockMovementId = StockMovement.Id`
- **Transfer** — Extension record for transfer-type movements
  - Join: `Transfer.StockMovementId = StockMovement.Id`

### Tables This Table References
- **MovementType** — Type enum (Delivery, Transfer, Adjustment)
  - Join: `StockMovement.MovementTypeId = MovementType.Id`
- **Site** — Receiving/delivery site
  - Join: `StockMovement.DeliverySiteId = Site.Id`
- **User** — Creator of the movement
  - Join: `StockMovement.CreatedBy = User.Id`

---

## Movement Type Values

| Id | Label | Description |
|----|-------|-------------|
| 1 | Adjustment | Stock count adjustments |
| 2 | Transfer | Inter-store stock transfers |
| 3 | Delivery | Supplier deliveries |

---

## Common Query Patterns

### Get Transfers for a Site (as sender or receiver)
```sql
SELECT sm.*, t.*
FROM {StockMovement} sm
INNER JOIN {Transfer} t ON t.StockMovementId = sm.Id
WHERE sm.MovementTypeId = 2
  AND (sm.DeliverySiteId = @SiteId OR t.FromSiteId = @SiteId)
```

### Get Movement with Line Count and Totals
```sql
SELECT
    sm.Id,
    sm.Date,
    COUNT(sml.Id) AS LineCount,
    SUM(sml.NetAmount) AS TotalNetAmount
FROM {StockMovement} sm
INNER JOIN {StockMovementLine} sml ON sml.StockMovementId = sm.Id
WHERE sm.MovementTypeId = 2
GROUP BY sm.Id, sm.Date
```

---

## Notes for OutSystems

- Use `{StockMovement}` in Advanced SQL
- `MovementTypeId = 2` for transfers
- `Date` is null for pending transfers — filter accordingly
- `DeliverySiteId` is the **receiving** site for transfers (not the sender)
- **Never join `{User}` to resolve `CreatedBy` name** — use the denormalized `CreatedByUserName` column instead. `{User}` is tenant-filtered and cross-tenant users return NULL. See [Transfer → Cross-Tenant Notes](../Transfer/README.md#cross-tenant-notes).

---

## Related Tables

- [StockMovementLine](../StockMovementLine/README.md) — Line items
- [Transfer](../Transfer/README.md) — Transfer extension record
- [MovementType](../MovementType/README.md) — Movement type enum
- [Site](../Site/README.md) — Delivery/receiving site
- [User](../User/README.md) — Creator

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-31 | Initial documentation from PRD 1.3 + OutSystems entity | Claude |
| 2026-04-12 | Added CreatedByUserName column for cross-tenant {User} workaround | Claude |
