# Table: BusinessUser

**OutSystems Entity**: BusinessUser
**Module**: Access_CS
**Purpose**: Represents an employee/staff member in the Maxtel system. Links to Person for identity and to various job/payroll/scheduling entities.
**Last Updated**: 2026-04-26

---

## Overview

BusinessUser is the core employee entity in Access_CS. Each row represents a staff member with their employment details (start/end dates, home site, payroll info, job classification, visa status, etc.). It does NOT have a direct Name column — identity comes from the related Person entity.

**Note**: Description says "Formerly [BusinessUser]" — entity was likely renamed/migrated at some point.

---

## Table Structure

### Columns

| Column Name | Data Type | Constraints | Description |
|-------------|-----------|-------------|-------------|
| `Id` | BIGINT | PK, NOT NULL | Auto-generated primary key |
| `BusinessId` | BIGINT | FK | References Business entity |
| `PersonId` | BIGINT | FK | References Person entity (for name/identity) |
| `HomeSiteId` | BIGINT | FK | Default/home site for this employee |
| `StartDate` | DATE | | Employment start date |
| `EndDate` | DATE | | Employment end date (null if current) |
| `IsActive` | BIT | | Whether employee is currently active |
| `IsDefault` | BIT | | Whether this is the default BusinessUser record |
| `LastUpdated` | DATETIME | | Last modification timestamp |
| `OTEmployee_Id` | BIGINT | | OpenTable employee ID reference |
| `Payroll_Id` | BIGINT | | Payroll system ID |
| `PayrollJobType_FunctionId` | BIGINT | FK | Payroll job type function reference |
| `TaxNumber` | VARCHAR | | Tax/IRD number |
| `PayrollJobTypeId` | BIGINT | FK | Payroll job type reference |
| `IsCitizen` | BIT | | Citizenship status |
| `TimeClockPin` | VARCHAR | | PIN for time clock system |
| `TimeClockPinLastUpdated` | DATETIME | | When PIN was last changed |
| `IsTimeClockPinUsed` | BIT | | Whether time clock PIN is in use |
| `JobLevel` | INT | | Job level/grade |
| `MaxPLExportLineNumber` | INT | | Max payroll export line number |
| `FavouriteBusinessUserJobId` | BIGINT | FK | Favourite job role reference |
| `PayrollBusinessUserJobId` | BIGINT | FK | Payroll job reference |
| `IsSystemPerson` | BIT | | Whether this is a system/service account |
| `NeedsVisa` | BIT | | Whether employee needs a work visa |
| `ConceptId` | BIGINT | FK | Concept/brand reference |
| `IsSchoolStudent` | BIT | | School student flag |
| `IsYear10OrBelow` | BIT | | Year 10 or below flag (AU) |
| `IsSchoolTrainee` | BIT | | School trainee flag |
| `VisaActive` | BIT | | Whether visa is currently active |
| `VisaExpiryDate` | DATE | | Visa expiration date |
| `VisaType` | VARCHAR | | Type of visa |
| `JobStatusCodeId` | BIGINT | FK | Job status code reference |
| `JobTypeCodeId` | BIGINT | FK | Job type code reference |
| `IsCrewTrainer` | BIT | | Crew trainer flag |
| `IsMaintenance` | BIT | | Maintenance role flag |
| `IsIfaPosition` | BIT | | IFA position flag |
| `PositionJobCodeId` | BIGINT | FK | Position job code reference |
| `VisaCodeId` | BIGINT | FK | Visa code reference |
| `AttendingSchoolId` | BIGINT | FK | School reference (if student) |
| `OldEmployeeNumber` | VARCHAR | | Legacy employee number |
| `PreferredNormalHours` | DECIMAL | | Preferred weekly hours |
| `EducationStatus` | VARCHAR | | Education status |
| `IsMultiSite` | BIT | | Whether employee works across multiple sites |
| `IsManager` | BIT | | Manager flag |
| `IsUnderAge` | BIT | | Under-age flag |
| `PositionJobId` | BIGINT | FK | Position job reference |
| `MaxShiftsPerWeek` | INT | | Maximum shifts per week |
| `MaxHoursPerWeek` | DECIMAL | | Maximum hours per week |
| `MaxHoursPerShift` | DECIMAL | | Maximum hours per shift |

---

## Key Constraints

### Primary Key
- `Id` - Auto-generated identifier

### Foreign Keys
- `PersonId` → Person.Id (for name/identity)
- `BusinessId` → Business.Id
- `HomeSiteId` → Site.Id
- `ConceptId` → Concept.Id
- Multiple job/payroll FK references

---

## Relationships

### Tables That Reference This Table
- **ReportFavourites** (NEW) - User's report favourites
  - Join: `ReportFavourites.BusinessUserId = BusinessUser.Id`
  - Note: Cross-service, stored by value

### Tables This Table References
- **Person** (Access_CS) - Employee identity (name, etc.)
  - Join: `BusinessUser.PersonId = Person.Id`

---

## Notes
- No direct Name column — get employee name via Person join
- Lives in Access_CS, cross-referenced by ID from Report_CS
- Expose Read Only = No

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-04-26 | Claude | Initial documentation from Service Studio screenshot |
