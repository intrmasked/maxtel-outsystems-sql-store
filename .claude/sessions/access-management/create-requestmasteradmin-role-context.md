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
| Field                | Value |
|----------------------|-------|
| Role Name            | RequestMasterAdmin |
| System Name          | RequestMasterAdmin |
| Is Active            | true |
| Is Maxtel Controlled | false |
| Description          | "Provides full administrative access (view, edit, and approve) to the Requests module and all request types within EmpApp_Roles." |

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

## Implementation Approach

**No SQL required.** This is a pure OutSystems development task.

### Approach: Option A — OR pattern in role checks

Every place in the EmpApp_Roles espace that checks one of the 15 existing roles, add an OR condition for the new RequestMasterAdmin role.

**Pattern:**
```
// Before
If CheckLeaveRequestAdmin(GetUserId()) Then

// After
If CheckLeaveRequestAdmin(GetUserId()) OR CheckRequestMasterAdmin(GetUserId()) Then
```

This applies to:
- Screen-level role checks (screen properties → Roles)
- Block/widget visibility conditions
- Server Action / Service Action permission guards
- Any `Check<RoleName>()` call in logic flows

### Step 1 — Create the role in EmpApp_Roles espace

In OutSystems Service Studio, EmpApp_Roles espace:
1. Go to **Roles** (in the Logic tab or Roles section)
2. Add new role:
   - Name: `RequestMasterAdmin`
   - Description: `Provides full administrative access (view, edit, and approve) to the Requests module and all request types within EmpApp_Roles.`
   - Is Active: `true`
   - Is Maxtel Controlled: `false`

### Step 2 — Find all role check points for the 15 roles

In the Requests app espace(s), search for every usage of:

```
CheckActiveChoiceAdmin
CheckCloseMiscRequest
CheckEmployeeJobHomesite
CheckEmployeeTerminationAdmin
CheckEAChoiceAdmin
CheckLeaveRequestAdmin
CheckLeaveType_DomesticViolence
CheckMiscRequestAdmin
CheckPermanentShiftAdmin
CheckPhotoRequestAdmin
CheckPreferredWorkingTimeAdmin
CheckRequestManagement
CheckPayrollAdministrator
CheckSwapShiftRequestAdmin
CheckTemporaryShiftAdmin
```

Use **Find & Replace** or **Find Usages** in Service Studio to locate all occurrences.

### Step 3 — Add OR condition at each check point

For each occurrence found in Step 2, extend the condition:
```
CheckLeaveRequestAdmin(GetUserId())
→ CheckLeaveRequestAdmin(GetUserId()) OR CheckRequestMasterAdmin(GetUserId())
```

Screen-level role assignments may need RequestMasterAdmin added directly to the screen's allowed roles list instead of modifying logic.

---

## Status

- [ ] In Progress
- **Current step:** Ready to begin OutSystems implementation — role creation + role check updates
- **Blockers:** None

---

## Key Decisions

- **No SQL** — This is entirely OutSystems logic, not a database migration.
- **Option A (OR pattern)** — Chosen over Option B (auto-assign 15 roles on assignment). Keeps implementation in the espace logic, consistent with how OutSystems roles work natively.
- **System Name = RequestMasterAdmin** — Confirmed unique per story spec.
- **Is Maxtel Controlled = false** — Explicitly required by story.
- **Additive** — No conflict if individual roles also assigned to a user.

---

## Next Steps

1. **Create role** in EmpApp_Roles espace (Service Studio)
2. **Audit all 15 role check usages** across the Requests app espace(s) using Find Usages
3. **Add OR CheckRequestMasterAdmin()** at every check point
4. **Test** — assign RequestMasterAdmin to a test user and verify access to all 15 areas
5. **Regression check** — confirm users without the role still cannot access

---

## Notes for Next Session

- The 15 role System Names map directly to `Check<SystemName>()` functions in OutSystems
- Screen-level role access is set in the screen properties (Roles field) — may need RequestMasterAdmin added there directly rather than in logic
- Story explicitly states: do NOT modify existing roles — additive only, OR pattern only
- This repo holds the context doc only — no query files needed for this story

## Quick Resume

To continue:
1. Read this file: `.claude/sessions/access-management/create-requestmasteradmin-role-context.md`
2. Open EmpApp_Roles espace in Service Studio
3. Continue from: **Step 1 — Create the role record in Service Studio**
