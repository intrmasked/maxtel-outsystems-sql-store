# Table: Transfer

**OutSystems Entity**: Transfer
**Module**: Stock (Stock_CS)
**Purpose**: Extension of StockMovement for inter-store stock transfer records
**Last Updated**: 2026-03-31

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
SELECT sm.Id, sm.Date, t.FromSiteId, sm.DeliverySiteId,
       u.Name AS ApprovedByName, t.ApprovedAt
FROM {Transfer} t
INNER JOIN {StockMovement} sm ON t.StockMovementId = sm.Id
LEFT JOIN {User} u ON t.ApprovedByUserId = u.Id
WHERE t.IsApproved = 1
  AND (t.FromSiteId = @SiteId OR sm.DeliverySiteId = @SiteId)
```

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
- Approval sets: IsApproved=1, ApprovedByUserId, ApprovedAt, and StockMovement.Date

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
