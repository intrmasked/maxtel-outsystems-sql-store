# Table: User

**OutSystems Entity**: User
**Module**: System
**Purpose**: End-user accounts for the application. Shared across eSpaces via the same user provider.
**Last Updated**: 2026-03-31

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

## Related Tables

- [StockMovement](../StockMovement/README.md) — CreatedBy
- [Transfer](../Transfer/README.md) — ApprovedByUserId

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-03-31 | Initial documentation from PRD 1.3 + OutSystems screenshot | Claude |
