# Table: MaxtelApp

**OutSystems Entity**: MaxtelApp
**Module**: Access_CS
**Purpose**: Friendly list of Apps/Modules as referenced by Marketing. Represents the operational modules in Maxtel Manager (e.g. Scheduling, Cash, Stock).
**Last Updated**: 2026-04-24

---

## Overview

MaxtelApp is a small lookup table in Access_CS that defines the operational modules/apps within the Maxtel ecosystem. Used to group features, reports, and permissions by module.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | BIGINT | PK, NOT NULL | Auto-generated primary key |
| `Name` | VARCHAR | NOT NULL | Module display name (e.g. "Scheduling", "Cash") |
| `Description` | VARCHAR | | Description of the module |
| `IsMaxtelControlled` | BIT | | Whether this module is controlled/managed by Maxtel |

---

## Key Constraints

### Primary Key
- `Id` - Auto-generated identifier

---

## Relationships

### Tables That Reference This Table
- **ReportModules** (NEW) - Maps SupportedReports to this module
  - Join: `ReportModules.MaxtelAppId = MaxtelApp.Id`
  - Note: No FK constraint (cross-service reference from Report_CS)

---

## Notes
- This is a **cross-service** table. It lives in Access_CS but is referenced by ID from Report_CS tables.
- Small lookup table — likely < 20 rows.
- Public = Yes, Expose Read Only = No

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-04-24 | Claude | Initial documentation from Service Studio screenshot |
