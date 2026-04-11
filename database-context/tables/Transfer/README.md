# Table: Transfer

**OutSystems Entity**: Transfer
**Module**: Stock (Stock_CS)
**Purpose**: Extension of StockMovement for inter-store stock transfer records
**Last Updated**: 2026-04-12

---

## Overview

`Transfer` is an extension table for `StockMovement` — it exists only for movements where `MovementTypeId = 2` (Transfer). It stores the sending site, approval status, and optional memo. The receiving site is stored on the parent `StockMovement.DeliverySiteId`.

A transfer has exactly two states:
- **Pending** (`IsApproved = false`) — Created by sending store, awaiting receiving store approval
- **Completed** (`IsApproved = true`) — Approved by receiving store, stock updates applied

There is no "declined" state — declining a transfer **hard deletes** the Transfer, StockMovement, and StockMovementLine records.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `StockMovementId` | Integer | PK, FK, NOT NULL | FK → StockMovement.Id. Also serves as PK (1:1 relationship) |
| `FromSiteId` | Integer | FK, NOT NULL | FK → Site.Id. The site **sending** the stock |
| `Comment` | NVarChar(500) | NULL | Optional memo entered by the sending store at creation |
| `IsApproved` | Bit | NOT NULL, DEFAULT 0 | false = Pending, true = Completed |
| `ApprovedByUserId` | Integer | FK, NULL | FK → User.Id. Set when receiving store approves |
| `ApprovedByUserName` | NVarChar | NULL | Denormalized snapshot of `User.Name` captured at approval time. See [Cross-Tenant Notes](#cross-tenant-notes) |
| `ApprovedAt` | DateTime | NULL | UTC timestamp of approval |

---

## Key Constraints

### Primary Key
- `StockMovementId` — Also the FK to StockMovement (1:1 extension pattern)

### Foreign Keys
- `StockMovementId` → `StockMovement`.`Id`
- `FromSiteId` → `Site`.`Id`
- `ApprovedByUserId` → `User`.`Id`

---

## Relationships

### Tables This Table References
- **StockMovement** — Parent movement record (1:1)
  - Join: `Transfer.StockMovementId = StockMovement.Id`
- **Site** (as FromSite) — The sending store
  - Join: `Transfer.FromSiteId = Site.Id`
- **User** (as ApprovedBy) — User who approved at receiving store
  - Join: `Transfer.ApprovedByUserId = User.Id`

### Site Mapping
- **Sending site**: `Transfer.FromSiteId` → `Site.Id`
- **Receiving site**: `StockMovement.DeliverySiteId` → `Site.Id`

---

## State Model

| State | IsApproved | Date (on StockMovement) | Description |
|-------|------------|------------------------|-------------|
| Pending | false | NULL | Awaiting receiving store approval |
| Completed | true | Set to business date | Approved, stock updated |
| *(Declined)* | *(deleted)* | *(deleted)* | Hard delete — no persisted state |

---

## Common Query Patterns

### Get Pending Transfers for a Site
```sql
SELECT sm.Id, t.FromSiteId, sm.DeliverySiteId, sm.CreatedAt
FROM {Transfer} t
INNER JOIN {StockMovement} sm ON t.StockMovementId = sm.Id
WHERE t.IsApproved = 0
  AND (t.FromSiteId = @SiteId OR sm.DeliverySiteId = @SiteId)
```

### Get Completed Transfers with Approval Info
```sql
-- Use denormalized name — do NOT join {User} (tenant-filtered)
SELECT sm.Id, sm.Date, t.FromSiteId, sm.DeliverySiteId,
       t.ApprovedByUserName, t.ApprovedAt
FROM {Transfer} t
INNER JOIN {StockMovement} sm ON t.StockMovementId = sm.Id
WHERE t.IsApproved = 1
  AND (t.FromSiteId = @SiteId OR sm.DeliverySiteId = @SiteId)
```

---

## Cross-Tenant Notes

Stock transfers can span tenants (e.g. a Mana site transferring stock to a Te Awamutu site in a different tenant). This creates two problems for name resolution in Advanced SQL queries:

1. **`{Site}` is tenant-filtered** — cross-tenant `Site` rows won't resolve via `{Site}` joins. Solved separately via `{SiteFavorties}` name fallback (see stock-transfers-list / stock-transfers-detail queries).

2. **`{User}` is tenant-filtered** — even though the underlying `User` table is physically shared across tenants, OutSystems applies tenant scoping to the `{User}` entity at the Advanced SQL layer. A query executed in Tenant A cannot resolve a user that belongs to Tenant B via a `{User}` join — the row comes back NULL.

### Denormalization workaround

Approver and creator names are captured **at write time** into denormalized columns on the owning tables, where `{User}` resolves correctly in the writing tenant's context:

- **`StockMovement.CreatedByUserName`** — written during transfer creation (sender's tenant)
- **`Transfer.ApprovedByUserName`** — written during transfer approval (receiver's tenant)

At read time, queries use these snapshot columns directly and never join `{User}`. This guarantees both sides of a cross-tenant transfer display correctly regardless of which tenant is viewing.

**Tradeoff**: Names are snapshots from the moment of action. If a user is renamed later, the old name persists on historical transfers. This is acceptable for an immutable audit record.

---

## Business Rules

- Only the **receiving store** (StockMovement.DeliverySiteId) can approve or decline
- The **sending store** implicitly authorises at creation — no separate outgoing approval
- Once approved, a transfer is **permanently read-only**
- Declining = hard delete (Transfer + StockMovement + StockMovementLines)
- `StockMovement.Date` is set to the local business date **at moment of approval**

---

## Notes for OutSystems

- Use `{Transfer}` in Advanced SQL
- Always join to `{StockMovement}` to get Date, DeliverySiteId, amounts
- `IsApproved` is a bit field: 0 = pending, 1 = completed
- Approval sets: IsApproved=1, ApprovedByUserId, **ApprovedByUserName** (snapshot of User.Name), ApprovedAt, and StockMovement.Date
- Creation sets: **StockMovement.CreatedByUserName** (snapshot of User.Name) alongside CreatedBy — see [StockMovement](../StockMovement/README.md)
- **Never join `{User}` to resolve approver/creator names** — use the denormalized columns instead. See [Cross-Tenant Notes](#cross-tenant-notes).

---

## Related Tables

- [StockMovement](../StockMovement/README.md) — Parent movement (1:1)
- [StockMovementLine](../StockMovementLine/README.md) — Line items (via StockMovement)
- [Site](../Site/README.md) — FromSiteId (sender) and DeliverySiteId (receiver)
- [User](../User/README.md) — ApprovedByUserId

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-31 | Initial documentation from PRD 1.3 | Claude |
| 2026-04-12 | Added ApprovedByUserName column + Cross-Tenant Notes section for {User} tenant-filter workaround | Claude |
