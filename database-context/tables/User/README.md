# Table: User

**OutSystems Entity**: User
**Module**: System
**Purpose**: End-user accounts for the application. Shared across eSpaces via the same user provider.
**Last Updated**: 2026-04-12

---

## Overview

`User` is the OutSystems system entity for application users. Used in stock management to track who created movements (`StockMovement.CreatedBy`) and who approved transfers (`Transfer.ApprovedByUserId`).

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | Integer | PK, NOT NULL | Primary key, auto-increment |
| `Name` | NVarChar | NOT NULL | Display name of the user |
| `Username` | NVarChar | NOT NULL, UNIQUE | Login username |
| `Password` | NVarChar | NOT NULL | Hashed password |
| `Email` | NVarChar | NULL | Email address |
| `MobilePhone` | NVarChar | NULL | Mobile phone number |
| `External_Id` | NVarChar | NULL | External system identifier |
| `Creation_Date` | DateTime | NOT NULL | Account creation timestamp |
| `Last_Login` | DateTime | NULL | Last login timestamp |
| `Is_Active` | Boolean | NOT NULL | Whether the user account is active |

---

## Key Constraints

### Primary Key
- `Id` — Unique identifier

### Unique Constraints
- `Username` — No duplicate usernames

---

## Relationships

### Tables That Reference This Table
- **StockMovement** — `CreatedBy` → `User.Id`
- **Transfer** — `ApprovedByUserId` → `User.Id`

---

## Common Query Patterns

### Get User Display Name for Joins
```sql
SELECT u.Name
FROM {User} u
WHERE u.Id = @UserId
```

### Join to StockMovement for Creator Name
```sql
SELECT sm.Id, u.Name AS CreatedByName
FROM {StockMovement} sm
INNER JOIN {User} u ON sm.CreatedBy = u.Id
```

---

## Notes for OutSystems

- Use `{User}` in Advanced SQL
- `Name` is the display name — use this for "Approved by" and "Created by" columns
- System entity — shared across all modules in the same user provider

---

## 🚨 CRITICAL: Cross-Tenant Limitation

**`{User}` is tenant-filtered at the OutSystems Advanced SQL runtime layer.**

Although the underlying `User` table is **physically shared** across tenants (same DB table, same rows), OutSystems applies tenant scoping to the `{User}` entity when you reference it from an Advanced SQL block. This means:

- A query executed **in Tenant A** cannot see users that belong to **Tenant B** via `{User}`
- `LEFT JOIN {User} u ON t.SomeUserId = u.Id` will return **NULL** for cross-tenant users
- The sandbox (MCP SQL bridge) does NOT apply this filter — queries resolve cross-tenant users fine there, which is misleading during testing
- **Symptom**: User name displays correctly when viewed by the same tenant that performed the action, but is blank when viewed by another tenant

### Workaround: Denormalize names at write time

Snapshot the user's display name onto the owning row **at the moment the action is performed** (while the current tenant still has visibility of its own user). Read from the snapshot column at query time — never join `{User}` for display purposes in cross-tenant contexts.

**Example**: Stock transfers between different tenants
- `StockMovement.CreatedByUserName` — written during transfer creation
- `Transfer.ApprovedByUserName` — written during transfer approval
- Detail query reads these columns directly, no `{User}` join

See [Transfer → Cross-Tenant Notes](../Transfer/README.md#cross-tenant-notes) for the full pattern.

### When `{User}` joins are still safe
- Queries that only ever run within a single tenant's scope (no cross-tenant references)
- Lookups for the **currently logged-in user** (always same-tenant by definition)
- Admin/reporting queries running outside a tenant filter (rare)

---

## Related Tables

- [StockMovement](../StockMovement/README.md) — CreatedBy
- [Transfer](../Transfer/README.md) — ApprovedByUserId

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-31 | Initial documentation from PRD 1.3 + OutSystems screenshot | Claude |
| 2026-04-12 | Added critical cross-tenant limitation warning — {User} is tenant-filtered at Advanced SQL layer | Claude |
