# Table: OT_LeaveBalance

**OutSystems Entity**: OT_LeaveBalance
**Module**: Leave_CS (or related leave module)
**Database Table**: {OT_LeaveBalance}
**Purpose**: Stores employee leave balances by leave type, with accrued/taken/available hours and payroll data.
**Last Updated**: 2026-05-24

---

## Overview

OT_LeaveBalance tracks leave entitlements and balances for employees. Each record represents a specific leave type balance for an employee at a site. It stores accrual, taken, adjustment, and availability figures along with pay-related fields used for leave calculations.

This table is consumed by the **GetLeaveBalanceForUser** service action which takes `BusinessUserId`, `LeaveTypeId`, and `AsAtDate` as inputs.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `id_LeaveBalance` | BIGINT | PK, NOT NULL | Primary key, auto-increment |
| `id_Emp` | BIGINT | FK, NOT NULL | The employee — links to an employee entity |
| `Date` | DATE | NOT NULL | The date this balance record is calculated for |
| `LeaveType` | VARCHAR/INT | NOT NULL | Type of leave (Annual, Sick, etc.) — may be FK or text |
| `id_Site` | BIGINT | FK | The site this balance belongs to |
| `SetupDate` | DATE | | Date the leave entitlement was set up |
| `Setup` | DECIMAL | | Initial setup/opening balance value |
| `Accrued` | DECIMAL | | Leave hours/days accrued |
| `AccruedOnUnpaidLeave` | DECIMAL | | Leave accrued during unpaid leave periods |
| `Taken` | DECIMAL | | Leave hours/days taken |
| `Adjustments` | DECIMAL | | Manual adjustments to the balance |
| `Available` | DECIMAL | | Current available leave balance (typically: Setup + Accrued - Taken + Adjustments) |
| `UnitOfCalculation` | VARCHAR/INT | | Unit used for calculation (e.g., hours, days, weeks) |
| `Value` | DECIMAL | | Monetary value of the leave balance |
| `EquivalentWeeks` | DECIMAL | | Leave balance expressed in equivalent weeks |
| `OrdinaryWeeklyPay` | DECIMAL | | Employee's ordinary weekly pay for leave calculations |
| `AverageWeeklyEarnings` | DECIMAL | | Average weekly earnings for leave calculations |
| `AverageDailyPay` | DECIMAL | | Average daily pay for leave calculations |
| `Terminated` | BIT | | Whether the employee has been terminated |
| `TakenInAdvance` | DECIMAL | | Leave taken in advance of entitlement |
| `TakenInAdvanceValue` | DECIMAL | | Monetary value of leave taken in advance |
| `id_EmployeeType` | BIGINT | FK | Links to employee type (e.g., full-time, part-time, casual) |
| `AvailableToSell` | DECIMAL | | Leave balance available for sell-back |

---

## Key Constraints

### Primary Key
- `id_LeaveBalance` - Unique identifier

### Foreign Keys
- `id_Emp` → Employee entity
- `id_Site` → Site entity
- `id_EmployeeType` → EmployeeType entity

---

## Entity Actions

- **CreateOT_LeaveBalance** - Create a new record
- **CreateOrUpdateOT_LeaveBalance** - Upsert
- **UpdateOT_LeaveBalance** - Update existing record
- **GetOT_LeaveBalance** - Get by Id
- **GetOT_LeaveBalanceForUpdate** - Get for update (locking)
- **DeleteOT_LeaveBalance** - Delete a record

---

## Service Action: GetLeaveBalanceForUser

**Module**: Leave_CS (Service Action)
**Inputs**: `BusinessUserId`, `LeaveTypeId`, `AsAtDate`
**Outputs**: Leave balance details including OrdinaryWeeklyPay, AverageWeeklyEarnings, ALAnniversaryDate

This service action is used by the Leave Release Detail screen to show leave balance information.

---

## Important Notes

- **Column naming convention**: Uses `id_` prefix for FKs (e.g., `id_Emp`, `id_Site`) — differs from the standard OutSystems `EntityId` convention. This is likely an external/imported table (OT = external system prefix).
- **Balance formula**: `Available = Setup + Accrued - Taken + Adjustments` (verify)
- **Pay fields**: `OrdinaryWeeklyPay`, `AverageWeeklyEarnings`, `AverageDailyPay` are used for NZ employment law leave payment calculations.

---

## Related Tables

- [BusinessUser](../BusinessUser/README.md) - Employee identity (linked via id_Emp or service action)
- [Site](../Site/README.md) - Site assignment

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-05-24 | Claude + Abdul | Initial documentation for story 3825 |
| 2026-05-24 | Claude + Abdul | Fixed columns from entity screenshot — full column list with id_Emp, Accrued, AccruedOnUnpaidLeave, Taken, Adjustments, Available, UnitOfCalculation, Value, EquivalentWeeks, AverageDailyPay, Terminated, TakenInAdvance, TakenInAdvanceValue, id_EmployeeType, AvailableToSell |
