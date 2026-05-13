# Session: Create RequestMasterAdmin Role - 2026-05-13

**Story Link:** https://dev.azure.com/MaxtelNZ/Scheduling/_workitems/edit/3817
**Mock:** N/A (role management — no UI mock)

---

## Original Story/Requirements

> Create New Role: RequestMasterAdmin — Full Access to Requests Module & All Request Types
>
> As a System Administrator, I want to create a new role called RequestMasterAdmin in the
> EmpApp_Roles Outsystems espace, so that authorised users can be granted consolidated full
> access (view, edit, and approve) to the Requests module and all current request types,
> without needing individual role assignments for each request type.

**Espace:** EmpApp_Roles
**App Name:** Requests
**Priority:** High

---

## Acceptance Criteria Summary

### Role Definition
| Field              | Value |
|--------------------|-------|
| Role Name          | RequestMasterAdmin |
| System Name        | RequestMasterAdmin |
| Is Active          | true |
| Is Maxtel Controlled | false |
| Description        | "Provides full administrative access (view, edit, and approve) to the Requests module and all request types within EmpApp_Roles." |

### Roles to Encompass (15 existing roles)

| Role Name | System Name | ID |
|-----------|-------------|-----|
| Active Choice | ActiveChoiceAdmin | 156 |
| Close Miscellaneous Request | CloseMiscRequest | 96 |
| Employee Change - Job or Home Site | EmployeeJobHomesite | 240 |
| Employee Change - Termination | EmployeeTerminationAdmin | 99 |
| Employment Agreement (EA) Choice | EAChoiceAdmin | 180 |
| Leave Requests - Admin | LeaveRequestAdmin | 91 |
| Leave Type - Domestic Violence | LeaveType_DomesticViolence | 136 |
| Miscellaneous Request - Admin | MiscRequestAdmin | 82 |
| Permanent Shift Advert - Admin | PermanentShiftAdmin | 100 |
| Photo Request - Admin | PhotoRequestAdmin | 179 |
| PWT & AMH - Admin | PreferredWorkingTimeAdmin | 83 |
| Request Management | RequestManagement | 210 |
| Setup Request (Payroll) + PNH + EC Setup | PayrollAdministrator | 86 |
| Shift Swap Request - Admin | SwapShiftRequestAdmin | 85 |
| Temporary Shift Advert - Admin | TemporaryShiftAdmin | 90 |

---

## Status

- [ ] In Progress
- **Current step:** Gathering table structure for EmpApp_Roles espace (roles table, permissions/access junction tables)
- **Blockers:** Need table schema for EmpApp_Roles database tables before writing SQL

---

## Tables Documentation Needed

These table docs **do not yet exist** — need to ask user for schema:

- `database-context/tables/[EmpApp_Roles role table]/` — NEW — stores role definitions (Name, SystemName, IsActive, IsMaxtelControlled, Description)
- `database-context/tables/[EmpApp_Roles permission junction table]/` — NEW — maps roles to access/permission entries

> **Action required**: Ask user for table names, columns, types, and relationships for the EmpApp_Roles espace tables.

---

## Queries to Create

```
queries/utilities/create-requestmasteradmin-role/
├── query.sql               # INSERT script for role creation + permission mappings
├── README.md
├── metadata.json
└── tests/
    └── test-ssms.sql       # Verification queries
```

**Category**: `utilities` — this is a one-time data migration/setup script, not a report query.

---

## Key Decisions

- **Category → utilities**: This is a one-time role provisioning script, not a recurring report. Fits `queries/utilities/`.
- **System Name = RequestMasterAdmin**: Confirmed unique per story spec.
- **Is Maxtel Controlled = false**: Explicitly required by story.
- **Additive role**: No conflict if individual roles also assigned — just a consolidated alias.

---

## Next Steps

1. **Get table schema** — Ask user for EmpApp_Roles table structure (role table + permission/access junction tables)
2. **Create table docs** — `database-context/tables/[table-name]/README.md` for each relevant table
3. **Write query.sql** — INSERT for role record + all permission mappings for the 15 covered roles
4. **Write test-ssms.sql** — SELECT verification query to confirm role was created correctly
5. **Run SQL Sandbox verification** via MCP bridge
6. **Commit and push** on branch `claude/create-requestmasteradmin-role-3oWCn`

---

## Notes for Next Session

- The 15 role IDs (82, 83, 85, 86, 90, 91, 96, 99, 100, 136, 156, 179, 180, 210, 240) are confirmed in the story — use these as reference for permission mapping
- OutSystems EmpApp_Roles is a separate espace from the main app — the SQL will target that espace's underlying database tables
- Story explicitly states: do NOT modify existing roles — additive only
- This is likely a `utilities` query — no DECLARE params needed unless we want to make it rerunnable with a rollback option

## Quick Resume

To continue:
1. Read this file: `.claude/sessions/access-management/create-requestmasteradmin-role-context.md`
2. Read table docs once created: `database-context/tables/[role-table]/README.md`
3. Check query: `queries/utilities/create-requestmasteradmin-role/query.sql`
4. Continue from: **Step 1 — Get table schema from user**
